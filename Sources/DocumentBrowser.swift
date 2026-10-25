import UIKit
import UniformTypeIdentifiers

/// 用 UIDocumentBrowserViewController 浏览并选择文件（与文件选择器是两套机制）
final class DocumentBrowser: NSObject, UIDocumentBrowserViewControllerDelegate {
    static let shared = DocumentBrowser()
    private var completion: (([URL]) -> Void)?

    func present(completion: @escaping ([URL]) -> Void) {
        self.completion = completion
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.keyWindow?.rootViewController
        else {
            completion([])
            return
        }
        let browser = UIDocumentBrowserViewController(forOpening: [.audio])
        browser.delegate = self
        browser.allowsDocumentCreation = false
        browser.allowsPickingMultipleItems = true
        browser.additionalLeadingNavigationBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        ]
        root.present(browser, animated: true)
    }

    func documentBrowser(_ controller: UIDocumentBrowserViewController,
                         didPickDocumentURLs documentURLs: [URL]) {
        let urls = documentURLs
        controller.dismiss(animated: true) {
            self.completion?(urls)
            self.completion = nil
        }
    }

    func documentBrowser(_ controller: UIDocumentBrowserViewController,
                         didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
        importHandler(nil, .none)
    }

    @objc private func cancelTapped() {
        UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })?
            .keyWindow?.rootViewController?.dismiss(animated: true)
        completion?([])
        completion = nil
    }
}
