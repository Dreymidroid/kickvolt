import Foundation
import UIKit

/// Presents `UIDocumentPickerViewController(forExporting:asCopy:)` so the user
/// can save exported beat-pack files to the Files app.
final class DocumentExportDelegate: NSObject, UIDocumentPickerDelegate {
  private var completion: ((Int64) -> Void)?

  init(completion: @escaping (Int64) -> Void) {
    self.completion = completion
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    finish(Int64(urls.count))
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish(0)
  }

  private func finish(_ count: Int64) {
    completion?(count)
    completion = nil
  }
}
