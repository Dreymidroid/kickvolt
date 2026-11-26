import AVFoundation
import Foundation

/// Encodes a 16-bit PCM WAV file to AAC-LC in an MPEG-4 container (.m4a) using
/// `AVAssetReader` and `AVAssetWriter` (`AVFileType.m4a`,
/// `kAudioFormatMPEG4AAC`), preserving sample rate and channel count.
enum M4aEncoder {
  static func encode(
    wavURL: URL,
    outURL: URL,
    bitrate: Int,
    cancel: CancelFlag,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws -> MediaInfo {
    let source: WavDecoder.Source
    do {
      source = try await WavDecoder.prepare(url: wavURL)
    } catch let e as PigeonError {
      throw audioError("encode_failed", e.message)
    } catch {
      throw audioError("encode_failed", error.localizedDescription)
    }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          try encodeBlocking(
            source: source,
            outURL: outURL,
            bitrate: bitrate,
            cancel: cancel,
            progress: progress
          )
          continuation.resume()
        } catch {
          try? FileManager.default.removeItem(at: outURL)
          continuation.resume(throwing: mapError(error))
        }
      }
    }

    progress(1.0)
    return try await probeMedia(url: outURL)
  }

  private static func encodeBlocking(
    source: WavDecoder.Source,
    outURL: URL,
    bitrate: Int,
    cancel: CancelFlag,
    progress: @escaping @Sendable (Double) -> Void
  ) throws {
    let fm = FileManager.default
    try? fm.createDirectory(
      at: outURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try? fm.removeItem(at: outURL)

    var layout = AudioChannelLayout()
    layout.mChannelLayoutTag =
      source.channels == 1 ? kAudioChannelLayoutTag_Mono : kAudioChannelLayoutTag_Stereo
    let layoutData = Data(bytes: &layout, count: MemoryLayout<AudioChannelLayout>.size)

    let readerSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: source.sampleRate,
      AVNumberOfChannelsKey: source.channels,
      AVChannelLayoutKey: layoutData,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]

    let reader: AVAssetReader
    do {
      reader = try AVAssetReader(asset: source.asset)
    } catch {
      throw audioError("encode_failed", error.localizedDescription)
    }
    let readerOutput = AVAssetReaderTrackOutput(
      track: source.track,
      outputSettings: readerSettings
    )
    readerOutput.alwaysCopiesSampleData = false
    guard reader.canAdd(readerOutput) else {
      throw audioError("encode_failed", "Can't read source WAV track.")
    }
    reader.add(readerOutput)

    let writer: AVAssetWriter
    do {
      writer = try AVAssetWriter(outputURL: outURL, fileType: .m4a)
    } catch {
      throw audioError("encode_failed", error.localizedDescription)
    }

    let writerSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: source.sampleRate,
      AVNumberOfChannelsKey: source.channels,
      AVChannelLayoutKey: layoutData,
      AVEncoderBitRateKey: bitrate,
    ]
    let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: writerSettings)
    writerInput.expectsMediaDataInRealTime = false
    guard writer.canAdd(writerInput) else {
      throw audioError(
        "encode_failed",
        "AAC encoder refused \(Int(source.sampleRate)) Hz / \(source.channels) ch."
      )
    }
    writer.add(writerInput)

    guard reader.startReading() else {
      throw mapError(reader.error ?? audioError("encode_failed", "Could not start reading WAV."))
    }
    guard writer.startWriting() else {
      reader.cancelReading()
      throw mapError(writer.error ?? audioError("encode_failed", "Could not start writing M4A."))
    }
    writer.startSession(atSourceTime: .zero)

    let queue = DispatchQueue(label: "com.kickvolt.app.m4aEncoder")
    let sema = DispatchSemaphore(value: 0)
    var loopError: Error?
    var finished = false
    var lastReported = -1.0

    writerInput.requestMediaDataWhenReady(on: queue) {
      if finished { return }
      while writerInput.isReadyForMoreMediaData {
        if cancel.isCancelled {
          finished = true
          writerInput.markAsFinished()
          reader.cancelReading()
          writer.cancelWriting()
          loopError = audioError("cancelled", "Export cancelled.")
          sema.signal()
          return
        }
        if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
          if !writerInput.append(sampleBuffer) {
            finished = true
            reader.cancelReading()
            writer.cancelWriting()
            loopError =
              writer.error
              ?? audioError("encode_failed", "Failed appending audio buffer to M4A.")
            sema.signal()
            return
          }
          if source.durationSeconds > 0 {
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            let p = min(max(pts / source.durationSeconds, 0), 1)
            if p - lastReported >= 0.01 {
              lastReported = p
              progress(p)
            }
          }
        } else {
          finished = true
          writerInput.markAsFinished()
          if reader.status == .failed {
            writer.cancelWriting()
            loopError =
              reader.error
              ?? audioError("encode_failed", "Failed reading WAV during M4A encode.")
            sema.signal()
          } else {
            writer.finishWriting {
              if writer.status == .failed {
                loopError =
                  writer.error
                  ?? audioError("encode_failed", "Failed finishing M4A file.")
              }
              sema.signal()
            }
          }
          return
        }
      }
    }

    sema.wait()
    if let err = loopError {
      throw err
    }
    if cancel.isCancelled {
      writer.cancelWriting()
      throw audioError("cancelled", "Export cancelled.")
    }
  }

  /// Probes duration and format of an audio file at [url] as iOS sees it.
  static func probeMedia(url: URL) async throws -> MediaInfo {
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw audioError("encode_failed", "Audio file not found: \(url.path)")
    }
    let asset = AVURLAsset(url: url)
    let tracks: [AVAssetTrack]
    let duration: CMTime
    do {
      tracks = try await asset.loadTracks(withMediaType: .audio)
      duration = try await asset.load(.duration)
    } catch {
      throw audioError("encode_failed", "Can't probe media: \(error.localizedDescription)")
    }
    guard let track = tracks.first else {
      throw audioError("no_audio_track", "File has no audio track.")
    }
    let descriptions = (try? await track.load(.formatDescriptions)) ?? []
    let asbd = descriptions.first.flatMap {
      CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee
    }
    let rate = Int64((asbd?.mSampleRate ?? 0) > 0 ? asbd!.mSampleRate : 44_100)
    let channels = Int64(min(max(Int(asbd?.mChannelsPerFrame ?? 2), 1), 2))
    let durationSeconds = duration.isNumeric ? max(0.0, duration.seconds) : 0.0
    let durationUs = Int64((durationSeconds * 1_000_000.0).rounded())
    let frameCount = Int64((durationSeconds * Double(rate)).rounded())
    return MediaInfo(
      sampleRate: rate,
      channels: channels,
      durationUs: durationUs,
      frameCount: frameCount
    )
  }

  private static func mapError(_ error: Error) -> Error {
    if error is PigeonError { return error }
    let ns = error as NSError
    if (ns.domain == NSPOSIXErrorDomain && ns.code == Int(ENOSPC))
      || (ns.domain == NSCocoaErrorDomain && ns.code == NSFileWriteOutOfSpaceError)
    {
      return audioError("disk_full", "Your phone ran out of space.")
    }
    if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
      if (underlying.domain == NSPOSIXErrorDomain && underlying.code == Int(ENOSPC))
        || (underlying.domain == NSCocoaErrorDomain
          && underlying.code == NSFileWriteOutOfSpaceError)
      {
        return audioError("disk_full", "Your phone ran out of space.")
      }
    }
    return audioError("encode_failed", ns.localizedDescription)
  }
}
