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
import UserNotifications

final class ShareViewController: SLComposeServiceViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        configureFirebase()
        autoHandleShare()
    }

    private func configureFirebase() {
        // Ensure Firebase is configured for the extension
        if FirebaseApp.app() == nil {
            guard let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
                  let options = FirebaseOptions(contentsOfFile: filePath) else {
                print("[ShareExt][Firebase] Missing GoogleService-Info.plist or invalid options")
                return
            }
            FirebaseApp.configure(options: options)
        }

        // Enable shared keychain access for Firebase Auth across the app + extensions
        // Make sure this access group exists in both the main app and the extension entitlements
        // and that Keychain Sharing is enabled with this exact identifier.
        let accessGroup = "L6HK4D37VH.group.org.valueminer.shared"
        do {
            try Auth.auth().useUserAccessGroup(accessGroup)
            print("[ShareExt][Firebase] Enabled user access group: \(accessGroup)")
        } catch {
            print("[ShareExt][Firebase] Failed to enable user access group (\(accessGroup)): \(error)")
        }

        // Optional: Log current user and token state for diagnostics
        if let user = Auth.auth().currentUser {
            print("[ShareExt][Firebase] Share Ext user: \(user.uid)")
        } else {
            print("[ShareExt][Firebase] No current user in Share Extension (sign-in may be required in host app)")
        }
    }

    private func autoHandleShare() {
        Task {
            guard let urlString = await extractURLString() else {
                showErrorAndClose("No valid URL found.")
                return
            }

            guard let user = await waitForCurrentUser() else {
                showErrorAndClose("Please sign in to ScrollMine first.")
                return
            }

            do {
                try await enqueueClip(urlString: urlString, userId: user.uid)
                await postSuccessNotificationIfAllowed()
                completeRequest()
            } catch {
                showErrorAndClose("Failed to submit. Try again.")
            }
        }
    }

    private func extractURLString() async -> String? {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else { return nil }

        // First try direct URL payload
        for provider in attachments where provider.hasItemConformingToTypeIdentifier("public.url") {
            if let url = await loadURL(from: provider, type: "public.url") {
                return url
            }
        }

        // Fallback: parse URL out of shared text
        for provider in attachments where provider.hasItemConformingToTypeIdentifier("public.text") {
            if let url = await loadURL(from: provider, type: "public.text") {
                return url
            }
        }

        return nil
    }

    private func loadURL(from provider: NSItemProvider, type: String) async -> String? {
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

    private func enqueueClip(urlString: String, userId: String) async throws {
        let db = Firestore.firestore()
        let doc = db.collection("clipQueue").document()

        try await doc.setData([
            "userId": userId,
            "url": urlString,
            "status": "queued",
            "createdAt": Timestamp(date: Date())
        ])
    }

    private func showErrorAndClose(_ message: String) {
        let alert = UIAlertController(title: "ScrollMine", message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.completeRequest()
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func waitForCurrentUser(timeout: TimeInterval = 0.3) async -> User? {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if let user = Auth.auth().currentUser {
                return user
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return Auth.auth().currentUser
    }

    private func postSuccessNotificationIfAllowed() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "ScrollMine"
        content.body = "Clip saved to ScrollMine! ✅"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            print("[ShareExt][Notification] Failed to schedule success notification:", error)
        }
    }

    override func isContentValid() -> Bool { true }
    override func didSelectPost() { }
    override func configurationItems() -> [Any]! { [] }
}
