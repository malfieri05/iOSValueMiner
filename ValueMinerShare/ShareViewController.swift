//
//  ShareViewController.swift
//  ValueMinerShare
//
//  Created by Michael Alfieri on 1/25/26.
//

import UIKit
import Social
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

final class ShareViewController: SLComposeServiceViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        configureFirebase()
        autoHandleShare()
    }

    private func configureFirebase() {
        if FirebaseApp.app() == nil {
            let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")!
            let options = FirebaseOptions(contentsOfFile: filePath)!
            FirebaseApp.configure(options: options)
        }
        try? Auth.auth().useUserAccessGroup("L6HK4D37VH.com.valueminer.shared")
        print("Share Ext user:", Auth.auth().currentUser?.uid ?? "nil")
    }

    private func autoHandleShare() {
        Task {
            guard let urlString = await extractURLString() else {
                showErrorAndClose("No valid URL found.")
                return
            }

            guard let user = Auth.auth().currentUser else {
                showErrorAndClose("Please sign in to ValueMiner first.")
                return
            }

            do {
                try await uploadClip(urlString: urlString, userId: user.uid)
                completeRequest()
            } catch {
                showErrorAndClose("Failed to save. Try again.")
            }
        }
    }

    private func extractURLString() async -> String? {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else { return nil }

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier("public.url") {
                return await loadItem(provider, type: "public.url")
            }
            if provider.hasItemConformingToTypeIdentifier("public.text") {
                return await loadItem(provider, type: "public.text")
            }
        }
        return nil
    }

    private func loadItem(_ provider: NSItemProvider, type: String) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url.absoluteString)
                } else if let text = item as? String {
                    continuation.resume(returning: self.extractURL(from: text))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func extractURL(from text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, options: [], range: range)?.url?.absoluteString
    }

    private func uploadClip(urlString: String, userId: String) async throws {
        let db = Firestore.firestore()
        let doc = db.collection("users")
            .document(userId)
            .collection("clips")
            .document()

        try await doc.setData([
            "url": urlString,
            "createdAt": Timestamp(date: Date())
        ])
    }

    private func showErrorAndClose(_ message: String) {
        let alert = UIAlertController(title: "ValueMiner", message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.completeRequest()
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    override func isContentValid() -> Bool { true }
    override func didSelectPost() { }
    override func configurationItems() -> [Any]! { [] }
}
