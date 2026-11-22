import AVFoundation
import Flutter
import MediaPlayer
import UIKit

/// iOS side of the Pigeon `AudioHostApi`. Pigeon calls these on the main
/// actor; heavy work is moved to a background queue.
final class AudioHostApiImpl: AudioHostApi {
  private let progressApi: AudioProgressApi
  private let jobsLock = NSLock()
  private var jobs: [String: CancelFlag] = [:]
  private var pickerDelegate: MusicPickerDelegate?

  init(messenger: FlutterBinaryMessenger) {
    progressApi = AudioProgressApi(binaryMessenger: messenger)
  }

  // MARK: Decode

  func decodeToWav(jobId: String, inputPath: String, outputPath: String) async throws
    -> DecodeResult
  {
    let flag = CancelFlag()
    setJob(jobId, flag)
    defer { setJob(jobId, nil) }

    let url: URL
    if inputPath.contains("://"), let parsed = URL(string: inputPath) {
      url = parsed
    } else {
      url = URL(fileURLWithPath: inputPath)
    }
    let source = try await WavDecoder.prepare(url: url)
    let outputURL = URL(fileURLWithPath: outputPath)
    let progressApi = self.progressApi

    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let result = try WavDecoder.read(source, to: outputURL, cancel: flag) { fraction in
            DispatchQueue.main.async {
              Task { @MainActor in
                try? await progressApi.onProgress(jobId: jobId, fraction: fraction)
              }
            }
          }
          continuation.resume(returning: result)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  func cancelJob(jobId: String) throws {
    jobsLock.lock()
    let flag = jobs[jobId]
    jobsLock.unlock()
    flag?.cancel()
  }

  private func setJob(_ id: String, _ flag: CancelFlag?) {
    jobsLock.lock()
    jobs[id] = flag
    jobsLock.unlock()
  }

  // MARK: Music library

  func pickFromMusicLibrary() async throws -> LibraryTrack? {
    let status: MPMediaLibraryAuthorizationStatus = await withCheckedContinuation { c in
      MPMediaLibrary.requestAuthorization { c.resume(returning: $0) }
    }
    guard status == .authorized else {
      throw audioError(
        "permission_denied", "Allow KickVolt to access your music in Settings to import songs.")
    }

    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async {
        guard let presenter = Self.topViewController() else {
          continuation.resume(throwing: audioError("decode_failed", "No screen to present on."))
          return
        }
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.allowsPickingMultipleItems = false
        // Cloud-only songs have no local file to read.
        picker.showsCloudItems = false
        picker.prompt = "Choose the song you're editing to"
        let delegate = MusicPickerDelegate { [weak self] result in
          self?.pickerDelegate = nil
          continuation.resume(with: result)
        }
        self.pickerDelegate = delegate
        picker.delegate = delegate
        presenter.present(picker, animated: true)
      }
    }
  }

  func listMusicLibrary() async throws -> [LibraryTrack] {
    throw audioError("unsupported", "Use pickFromMusicLibrary on iOS.")
  }

  func copyContentUri(uri: String, destPath: String) async throws {
    throw audioError("unsupported", "content:// URIs are Android only.")
  }

  func freeDiskBytes(path: String) throws -> Int64 {
    WavDecoder.freeBytes(at: URL(fileURLWithPath: path))
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window =
      scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
      ?? scenes.first?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}

/// MPMediaPickerController delegate that resolves once.
final class MusicPickerDelegate: NSObject, MPMediaPickerControllerDelegate {
  private var completion: ((Result<LibraryTrack?, Error>) -> Void)?

  init(completion: @escaping (Result<LibraryTrack?, Error>) -> Void) {
    self.completion = completion
  }

  func mediaPicker(
    _ mediaPicker: MPMediaPickerController,
    didPickMediaItems mediaItemCollection: MPMediaItemCollection
  ) {
    mediaPicker.dismiss(animated: true)
    guard let item = mediaItemCollection.items.first else {
      finish(.success(nil))
      return
    }
    // assetURL is nil for DRM-protected (Apple Music) and not-downloaded songs.
    guard let url = item.assetURL else {
      if item.isCloudItem && !item.hasProtectedAsset {
        finish(
          .failure(
            audioError(
              "cloud_item", "This song isn't downloaded to your phone. Download it and try again.")))
      } else {
        finish(
          .failure(
            audioError(
              "drm_protected",
              "This song is copy-protected (Apple Music), so it can't be imported. Use a song you own, or a video with the audio."
            )))
      }
      return
    }
    finish(
      .success(
        LibraryTrack(
          id: String(item.persistentID),
          title: item.title ?? "Untitled",
          artist: item.artist,
          durationMs: Int64(item.playbackDuration * 1000),
          uri: url.absoluteString
        )))
  }

  func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
    mediaPicker.dismiss(animated: true)
    finish(.success(nil))
  }

  private func finish(_ result: Result<LibraryTrack?, Error>) {
    completion?(result)
    completion = nil
  }
}
