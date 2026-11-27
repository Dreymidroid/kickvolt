import AVFoundation
import CoreGraphics
import CoreText
import CoreVideo
import Foundation

/// Encodes the M7 guide video with `AVAssetWriter` (`.mp4`): an H.264 video
/// input fed through an `AVAssetWriterInputPixelBufferAdaptor` with frames
/// drawn by CoreGraphics/CoreText, plus an AAC audio input fed with the guide
/// WAV's PCM (the same reader/writer settings as `M4aEncoder`).
///
/// Every frame `k` is appended with `CMTime(value: k, timescale: fps)`; the
/// timing comes only from the frame index. Identical looks (black, "white with
/// N", "black with N", "dim N") are drawn once and the same pixel buffer is
/// appended again.
enum GuideVideoEncoder {
  static func encode(
    spec: GuideVideoSpec,
    cancel: CancelFlag,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws -> MediaInfo {
    let fm = FileManager.default
    let outURL = URL(fileURLWithPath: spec.outPath)
    let dir = outURL.deletingLastPathComponent()
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

    // AVURLAsset identifies the WAV by its extension; the WAV pack hands us
    // the staged `<name>.wav.part`, so read it through a `.wav` hard link.
    var wavURL = URL(fileURLWithPath: spec.audioWavPath)
    var wavLink: URL?
    if wavURL.pathExtension.lowercased() != "wav" {
      let link = dir.appendingPathComponent(".\(UUID().uuidString).wav")
      do {
        try fm.linkItem(at: wavURL, to: link)
      } catch {
        try fm.copyItem(at: wavURL, to: link)
      }
      wavLink = link
      wavURL = link
    }
    defer {
      if let link = wavLink { try? fm.removeItem(at: link) }
    }

    let source: WavDecoder.Source
    do {
      source = try await WavDecoder.prepare(url: wavURL)
    } catch let e as PigeonError {
      throw audioError("encode_failed", e.message)
    } catch {
      throw audioError("encode_failed", error.localizedDescription)
    }

    // Write to a sibling `.mp4` (AVURLAsset needs the extension to probe it),
    // then move it to `outURL` (`.mp4.part`).
    let workingURL = dir.appendingPathComponent(".\(UUID().uuidString).mp4")

    do {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, Error>) in
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            try encodeBlocking(
              spec: spec,
              source: source,
              outURL: workingURL,
              cancel: cancel,
              progress: progress
            )
            continuation.resume()
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
      let info = try await M4aEncoder.probeMedia(url: workingURL)
      try? fm.removeItem(at: outURL)
      try fm.moveItem(at: workingURL, to: outURL)
      progress(1.0)
      return info
    } catch {
      try? fm.removeItem(at: workingURL)
      try? fm.removeItem(at: outURL)
      throw mapError(error)
    }
  }

  // MARK: Frame looks

  private enum Look: Hashable {
    case black
    case flash(Int)  // white, number in black
    case after(Int)  // black, number in white
    case dim(Int)  // black, number in white at 40%

    var number: Int? {
      switch self {
      case .black: return nil
      case .flash(let n), .after(let n), .dim(let n): return n
      }
    }
  }

  private static func look(
    frame k: Int, flashIndex: Int, flashFrames: [Int], beatNumbers: [Int]
  ) -> Look {
    if flashIndex < 0 { return .black }
    let f = flashFrames[flashIndex]
    let n = beatNumbers[flashIndex]
    if k == f { return .flash(n) }
    if k == f + 1 { return .after(n) }
    return .dim(n)
  }

  private static func draw(_ look: Look, into buffer: CVPixelBuffer) throws {
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    let width = CVPixelBufferGetWidth(buffer)
    let height = CVPixelBufferGetHeight(buffer)
    guard
      let base = CVPixelBufferGetBaseAddress(buffer),
      let ctx = CGContext(
        data: base,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
          | CGBitmapInfo.byteOrder32Little.rawValue
      )
    else {
      throw audioError("encode_failed", "Can't draw a video frame.")
    }

    let background: CGColor
    let number: Int?
    let textColor: CGColor
    switch look {
    case .black:
      background = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
      number = nil
      textColor = background
    case .flash(let n):
      background = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
      number = n
      textColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    case .after(let n):
      background = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
      number = n
      textColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    case .dim(let n):
      background = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
      number = n
      textColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.4)
    }
    ctx.setFillColor(background)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let n = number else { return }

    // Bold system font at ~40% of the height, shrunk to fit 90% of the width.
    func line(size: CGFloat) -> CTLine {
      let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, size, nil)
        ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
      let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): textColor,
      ]
      return CTLineCreateWithAttributedString(
        NSAttributedString(string: String(n), attributes: attrs))
    }
    var size = CGFloat(height) * 0.4
    var textLine = line(size: size)
    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    var leading: CGFloat = 0
    var lineWidth = CGFloat(CTLineGetTypographicBounds(textLine, &ascent, &descent, &leading))
    let maxWidth = CGFloat(width) * 0.9
    if lineWidth > maxWidth {
      size *= maxWidth / lineWidth
      textLine = line(size: size)
      lineWidth = CGFloat(CTLineGetTypographicBounds(textLine, &ascent, &descent, &leading))
    }
    // CoreGraphics is y-up here; centre the glyph box vertically.
    let x = (CGFloat(width) - lineWidth) / 2
    let baseline = CGFloat(height) / 2 - (ascent - descent) / 2
    ctx.textPosition = CGPoint(x: x, y: baseline)
    CTLineDraw(textLine, ctx)
  }

  // MARK: Writer

  private static func videoSettings(width: Int, height: Int, fps: Int, bitrate: Int)
    -> [String: Any]
  {
    [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: bitrate,
        AVVideoMaxKeyFrameIntervalKey: fps,
        AVVideoExpectedSourceFrameRateKey: fps,
      ],
    ]
  }

  private static func encodeBlocking(
    spec: GuideVideoSpec,
    source: WavDecoder.Source,
    outURL: URL,
    cancel: CancelFlag,
    progress: @escaping @Sendable (Double) -> Void
  ) throws {
    let fps = Int(spec.fps)
    let totalFrames = Int(spec.totalFrames)
    let flashFrames = spec.flashFrames.map { Int($0) }
    let beatNumbers = spec.beatNumbers.map { Int($0) }
    guard fps > 0, totalFrames > 0, flashFrames.count == beatNumbers.count else {
      throw audioError("encode_failed", "Invalid guide video spec.")
    }
    try? FileManager.default.removeItem(at: outURL)

    let writer: AVAssetWriter
    do {
      writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
    } catch {
      throw audioError("encode_failed", error.localizedDescription)
    }

    // Video input; fall back to 720 x 1280 if 1080 x 1920 is refused.
    var chosen: (width: Int, height: Int, settings: [String: Any])?
    for (w, h) in [(Int(spec.width), Int(spec.height)), (720, 1280)] {
      let s = videoSettings(width: w, height: h, fps: fps, bitrate: Int(spec.videoBitrate))
      if writer.canApply(outputSettings: s, forMediaType: .video) {
        chosen = (w, h, s)
        break
      }
    }
    guard let video = chosen else {
      throw audioError("encode_failed", "H.264 encoder refused the guide video size.")
    }
    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: video.settings)
    videoInput.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: videoInput,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: video.width,
        kCVPixelBufferHeightKey as String: video.height,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
      ]
    )
    guard writer.canAdd(videoInput) else {
      throw audioError("encode_failed", "Can't add the video track.")
    }
    writer.add(videoInput)

    // Audio input: the guide WAV, AAC-encoded (M6 settings).
    var layout = AudioChannelLayout()
    layout.mChannelLayoutTag =
      source.channels == 1 ? kAudioChannelLayoutTag_Mono : kAudioChannelLayoutTag_Stereo
    let layoutData = Data(bytes: &layout, count: MemoryLayout<AudioChannelLayout>.size)
    let reader: AVAssetReader
    do {
      reader = try AVAssetReader(asset: source.asset)
    } catch {
      throw audioError("encode_failed", error.localizedDescription)
    }
    let readerOutput = AVAssetReaderTrackOutput(
      track: source.track,
      outputSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: source.sampleRate,
        AVNumberOfChannelsKey: source.channels,
        AVChannelLayoutKey: layoutData,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
      ]
    )
    readerOutput.alwaysCopiesSampleData = false
    guard reader.canAdd(readerOutput) else {
      throw audioError("encode_failed", "Can't read the guide track.")
    }
    reader.add(readerOutput)
    let audioInput = AVAssetWriterInput(
      mediaType: .audio,
      outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: source.sampleRate,
        AVNumberOfChannelsKey: source.channels,
        AVChannelLayoutKey: layoutData,
        AVEncoderBitRateKey: Int(spec.audioBitrate),
      ]
    )
    audioInput.expectsMediaDataInRealTime = false
    guard writer.canAdd(audioInput) else {
      throw audioError("encode_failed", "AAC encoder refused the guide track.")
    }
    writer.add(audioInput)

    guard reader.startReading() else {
      throw reader.error ?? audioError("encode_failed", "Could not read the guide track.")
    }
    guard writer.startWriting() else {
      reader.cancelReading()
      throw writer.error ?? audioError("encode_failed", "Could not start the guide video.")
    }
    writer.startSession(atSourceTime: .zero)

    // Both inputs are fed on one serial queue, so the state below is only
    // touched from it.
    let queue = DispatchQueue(label: "com.kickvolt.app.guideVideoEncoder")
    let group = DispatchGroup()
    var failure: Error?
    var stopped = false
    var videoDone = false
    var audioDone = false

    func stop(_ error: Error) {
      if stopped { return }
      stopped = true
      failure = error
      reader.cancelReading()
      writer.cancelWriting()
      if !videoDone {
        videoDone = true
        group.leave()
      }
      if !audioDone {
        audioDone = true
        group.leave()
      }
    }

    // Video.
    var k = 0
    var flashIndex = -1
    var cache: [Look: CVPixelBuffer] = [:]
    var lastReported = -1.0
    group.enter()
    videoInput.requestMediaDataWhenReady(on: queue) {
      if videoDone { return }
      while videoInput.isReadyForMoreMediaData && !stopped {
        if cancel.isCancelled {
          stop(audioError("cancelled", "Export cancelled."))
          return
        }
        if k >= totalFrames {
          videoInput.markAsFinished()
          videoDone = true
          group.leave()
          return
        }
        while flashIndex + 1 < flashFrames.count && flashFrames[flashIndex + 1] <= k {
          flashIndex += 1
        }
        let frameLook = GuideVideoEncoder.look(
          frame: k, flashIndex: flashIndex, flashFrames: flashFrames, beatNumbers: beatNumbers)
        var buffer = cache[frameLook]
        if buffer == nil {
          guard let pool = adaptor.pixelBufferPool else {
            stop(writer.error ?? audioError("encode_failed", "No pixel buffer pool."))
            return
          }
          var created: CVPixelBuffer?
          let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &created)
          guard status == kCVReturnSuccess, let pb = created else {
            stop(audioError("encode_failed", "Can't allocate a video frame (\(status))."))
            return
          }
          do {
            try GuideVideoEncoder.draw(frameLook, into: pb)
          } catch {
            stop(error)
            return
          }
          // Keep black plus the current beat's looks only.
          if case .black = frameLook {
          } else {
            cache = cache.filter { key, _ in
              if case .black = key { return true }
              return key.number == frameLook.number
            }
          }
          cache[frameLook] = pb
          buffer = pb
        }
        // The frame's time is exactly k / fps.
        if !adaptor.append(buffer!, withPresentationTime: CMTime(value: Int64(k), timescale: Int32(fps))) {
          stop(writer.error ?? audioError("encode_failed", "Failed appending a video frame."))
          return
        }
        k += 1
        let p = Double(k) / Double(totalFrames)
        if p - lastReported >= 0.01 {
          lastReported = p
          progress(p)
        }
      }
    }

    // Audio.
    group.enter()
    audioInput.requestMediaDataWhenReady(on: queue) {
      if audioDone { return }
      while audioInput.isReadyForMoreMediaData && !stopped {
        if cancel.isCancelled {
          stop(audioError("cancelled", "Export cancelled."))
          return
        }
        if let sample = readerOutput.copyNextSampleBuffer() {
          if !audioInput.append(sample) {
            stop(writer.error ?? audioError("encode_failed", "Failed appending guide audio."))
            return
          }
        } else {
          if reader.status == .failed {
            stop(reader.error ?? audioError("encode_failed", "Failed reading the guide track."))
            return
          }
          audioInput.markAsFinished()
          audioDone = true
          group.leave()
          return
        }
      }
    }

    group.wait()

    var result: Error?
    queue.sync { result = failure }
    if let error = result { throw error }
    if cancel.isCancelled {
      writer.cancelWriting()
      throw audioError("cancelled", "Export cancelled.")
    }

    // The file ends exactly at totalFrames / fps.
    writer.endSession(atSourceTime: CMTime(value: Int64(totalFrames), timescale: Int32(fps)))
    let finished = DispatchSemaphore(value: 0)
    writer.finishWriting { finished.signal() }
    finished.wait()
    if writer.status != .completed {
      throw writer.error ?? audioError("encode_failed", "Failed finishing the guide video.")
    }
  }

  private static func mapError(_ error: Error) -> Error {
    if error is PigeonError { return error }
    let ns = error as NSError
    let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError
    for e in [ns, underlying].compactMap({ $0 }) {
      if (e.domain == NSPOSIXErrorDomain && e.code == Int(ENOSPC))
        || (e.domain == NSCocoaErrorDomain && e.code == NSFileWriteOutOfSpaceError)
      {
        return audioError("disk_full", "Your phone ran out of space.")
      }
    }
    return audioError("encode_failed", ns.localizedDescription)
  }
}

