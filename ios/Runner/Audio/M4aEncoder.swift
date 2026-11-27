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

    // AVURLAsset relies on the `.m4a` path extension to identify the container
    // when probing; if the caller passed a `.part` staging path, write and
    // probe a sibling `.m4a` temp file and move it into `outURL` on success.
    let needsTempM4a = outURL.pathExtension.lowercased() != "m4a"
    let workingURL =
      needsTempM4a
      ? outURL.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).m4a")
      : outURL

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          try encodeBlocking(
            source: source,
            outURL: workingURL,
            bitrate: bitrate,
            cancel: cancel,
            progress: progress
          )
          continuation.resume()
        } catch {
          try? FileManager.default.removeItem(at: workingURL)
          continuation.resume(throwing: mapError(error))
        }
      }
    }

    let info: MediaInfo
    do {
      info = try await probeMedia(url: workingURL)
      if needsTempM4a {
        let fm = FileManager.default
        try? fm.removeItem(at: outURL)
        try fm.moveItem(at: workingURL, to: outURL)
      }
    } catch {
      try? FileManager.default.removeItem(at: workingURL)
      throw mapError(error)
    }

    progress(1.0)
    return info
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

    // M7: a video track (the guide video). Frames are counted by reading the
    // track's compressed samples (no decoding).
    let videoTracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
    guard let videoTrack = videoTracks.first else {
      return MediaInfo(
        sampleRate: rate,
        channels: channels,
        durationUs: durationUs,
        frameCount: frameCount,
        hasVideo: false
      )
    }
    let size = (try? await videoTrack.load(.naturalSize)) ?? .zero
    let range = try? await videoTrack.load(.timeRange)
    let videoDurationUs = range.map { r -> Int64 in
      r.duration.isNumeric ? Int64((r.duration.seconds * 1_000_000.0).rounded()) : 0
    }
    var videoFrames: Int64?
    if let reader = try? AVAssetReader(asset: asset) {
      let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
      output.alwaysCopiesSampleData = false
      if reader.canAdd(output) {
        reader.add(output)
        if reader.startReading() {
          var count: Int64 = 0
          while let sample = output.copyNextSampleBuffer() {
            count += Int64(CMSampleBufferGetNumSamples(sample))
          }
          if reader.status == .completed { videoFrames = count }
        }
      }
    }
    return MediaInfo(
      sampleRate: rate,
      channels: channels,
      durationUs: durationUs,
      frameCount: frameCount,
      hasVideo: true,
      videoWidth: Int64(size.width.rounded()),
      videoHeight: Int64(size.height.rounded()),
      videoFrameCount: videoFrames,
      videoDurationUs: videoDurationUs
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
