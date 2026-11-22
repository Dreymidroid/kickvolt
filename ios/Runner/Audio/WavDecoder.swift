import AVFoundation
import Foundation

/// Thread-safe cancel flag shared between the Pigeon handler and a decode.
final class CancelFlag: @unchecked Sendable {
  private let lock = NSLock()
  private var value = false

  var isCancelled: Bool {
    lock.lock()
    defer { lock.unlock() }
    return value
  }

  func cancel() {
    lock.lock()
    value = true
    lock.unlock()
  }
}

func audioError(_ code: String, _ message: String?) -> PigeonError {
  PigeonError(code: code, message: message, details: nil)
}

/// Decodes the first audio track of an asset (audio file, video, or an
/// `ipod-library://` URL) to a 16-bit little-endian interleaved PCM WAV with
/// AVAssetReader, streaming to disk.
enum WavDecoder {
  struct Source {
    let asset: AVURLAsset
    let track: AVAssetTrack
    let sampleRate: Double
    let channels: Int
    let durationSeconds: Double
  }

  /// Loads the track and checks protection. Runs the async AVFoundation
  /// property loads (iOS 15+).
  static func prepare(url: URL) async throws -> Source {
    let asset = AVURLAsset(url: url)
    let tracks: [AVAssetTrack]
    let isProtected: Bool
    let duration: CMTime
    do {
      tracks = try await asset.loadTracks(withMediaType: .audio)
      isProtected = try await asset.load(.hasProtectedContent)
      duration = try await asset.load(.duration)
    } catch {
      throw audioError("unsupported_format", "Can't read this file: \(error.localizedDescription)")
    }
    if isProtected { throw audioError("drm_protected", "This song is copy-protected.") }
    guard let track = tracks.first else {
      throw audioError("no_audio_track", "This file has no audio track.")
    }
    let descriptions = (try? await track.load(.formatDescriptions)) ?? []
    let asbd = descriptions.first.flatMap {
      CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee
    }
    let rate = (asbd?.mSampleRate ?? 0) > 0 ? asbd!.mSampleRate : 44_100
    let channels = Int(asbd?.mChannelsPerFrame ?? 2)
    return Source(
      asset: asset,
      track: track,
      sampleRate: rate,
      channels: min(max(channels, 1), 2),
      durationSeconds: duration.isNumeric ? duration.seconds : 0
    )
  }

  /// Blocking; call off the main thread.
  static func read(
    _ source: Source,
    to outputURL: URL,
    cancel: CancelFlag,
    progress: (Double) -> Void
  ) throws -> DecodeResult {
    do {
      return try readInternal(source, to: outputURL, cancel: cancel, progress: progress)
    } catch {
      try? FileManager.default.removeItem(at: outputURL)
      throw mapError(error)
    }
  }

  private static func readInternal(
    _ source: Source,
    to outputURL: URL,
    cancel: CancelFlag,
    progress: (Double) -> Void
  ) throws -> DecodeResult {
    try checkFreeSpace(at: outputURL, source: source)

    var layout = AudioChannelLayout()
    layout.mChannelLayoutTag =
      source.channels == 1 ? kAudioChannelLayoutTag_Mono : kAudioChannelLayoutTag_Stereo
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: source.sampleRate,
      AVNumberOfChannelsKey: source.channels,
      AVChannelLayoutKey: Data(bytes: &layout, count: MemoryLayout<AudioChannelLayout>.size),
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]

    let reader: AVAssetReader
    do {
      reader = try AVAssetReader(asset: source.asset)
    } catch {
      throw audioError("unsupported_format", error.localizedDescription)
    }
    let output = AVAssetReaderTrackOutput(track: source.track, outputSettings: settings)
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else {
      throw audioError("unsupported_format", "Can't decode this audio track.")
    }
    reader.add(output)
    guard reader.startReading() else {
      throw audioError("decode_failed", reader.error?.localizedDescription)
    }

    let fm = FileManager.default
    try? fm.createDirectory(
      at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    fm.createFile(atPath: outputURL.path, contents: nil)
    let handle = try FileHandle(forWritingTo: outputURL)
    defer { try? handle.close() }
    try handle.truncate(atOffset: 0)
    try handle.write(contentsOf: Data(count: 44))

    var dataBytes = 0
    var lastReported = -1.0
    while let buffer = output.copyNextSampleBuffer() {
      if cancel.isCancelled {
        reader.cancelReading()
        throw audioError("cancelled", "Import cancelled.")
      }
      guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
      let length = CMBlockBufferGetDataLength(block)
      if length == 0 { continue }
      var chunk = Data(count: length)
      let status = chunk.withUnsafeMutableBytes { raw -> OSStatus in
        CMBlockBufferCopyDataBytes(
          block, atOffset: 0, dataLength: length, destination: raw.baseAddress!)
      }
      guard status == kCMBlockBufferNoErr else {
        throw audioError("decode_failed", "Couldn't read decoded audio (\(status)).")
      }
      try handle.write(contentsOf: chunk)
      dataBytes += length

      if source.durationSeconds > 0 {
        let pts = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
        let p = min(max(pts / source.durationSeconds, 0), 1)
        if p - lastReported >= 0.01 {
          lastReported = p
          progress(p)
        }
      }
    }

    if reader.status == .failed {
      throw audioError("decode_failed", reader.error?.localizedDescription)
    }
    if cancel.isCancelled { throw audioError("cancelled", "Import cancelled.") }
    if dataBytes == 0 { throw audioError("decode_failed", "The decoder produced no audio.") }

    try handle.seek(toOffset: 0)
    try handle.write(
      contentsOf: wavHeader(
        sampleRate: Int(source.sampleRate), channels: source.channels, dataBytes: dataBytes))
    progress(1)
    return DecodeResult(
      sampleRate: Int64(source.sampleRate),
      channels: Int64(source.channels),
      frameCount: Int64(dataBytes / (2 * source.channels))
    )
  }

  static func freeBytes(at url: URL) -> Int64 {
    var dir = url
    while !FileManager.default.fileExists(atPath: dir.path), dir.pathComponents.count > 1 {
      dir = dir.deletingLastPathComponent()
    }
    let values = try? dir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
    return values?.volumeAvailableCapacityForImportantUsage ?? Int64.max
  }

  private static func checkFreeSpace(at url: URL, source: Source) throws {
    guard source.durationSeconds > 0 else { return }
    let needed = Int64(source.durationSeconds * source.sampleRate) * Int64(source.channels * 2)
      + 20 * 1024 * 1024
    if freeBytes(at: url) < needed {
      throw audioError("disk_full", "Not enough free space to import this song.")
    }
  }

  private static func mapError(_ error: Error) -> Error {
    if error is PigeonError { return error }
    let ns = error as NSError
    if (ns.domain == NSPOSIXErrorDomain && ns.code == Int(ENOSPC))
      || (ns.domain == NSCocoaErrorDomain && ns.code == NSFileWriteOutOfSpaceError)
    {
      return audioError("disk_full", "Your phone ran out of space.")
    }
    return audioError("decode_failed", ns.localizedDescription)
  }

  /// Canonical 44-byte PCM WAV header (16-bit).
  static func wavHeader(sampleRate: Int, channels: Int, dataBytes: Int) -> Data {
    var d = Data(capacity: 44)
    func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
    func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
    let blockAlign = channels * 2
    d.append(contentsOf: Array("RIFF".utf8))
    u32(UInt32(36 + dataBytes))
    d.append(contentsOf: Array("WAVE".utf8))
    d.append(contentsOf: Array("fmt ".utf8))
    u32(16)
    u16(1)
    u16(UInt16(channels))
    u32(UInt32(sampleRate))
    u32(UInt32(sampleRate * blockAlign))
    u16(UInt16(blockAlign))
    u16(16)
    d.append(contentsOf: Array("data".utf8))
    u32(UInt32(dataBytes))
    return d
  }
}
