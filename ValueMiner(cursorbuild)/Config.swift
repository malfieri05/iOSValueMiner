//
//  Config.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/23/26.
//

import Foundation

enum Config {
    private static let secrets: [String: Any] = {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            assertionFailure("Secrets.plist missing or unreadable.")
            return [:]
        }
        return dict
    }()

    private static func requiredString(forKey key: String) -> String {
        guard let value = secrets[key] as? String else {
            assertionFailure("\(key) missing in Secrets.plist")
            return ""
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            assertionFailure("\(key) is empty in Secrets.plist")
            return ""
        }
        return trimmed
    }

    private static func optionalURLString(forKey key: String) -> URL? {
        guard let value = secrets[key] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    static var searchApiKey: String {
        requiredString(forKey: "SEARCH_API_KEY")
    }

    static var supadataApiKey: String {
        requiredString(forKey: "SUPADATA_API_KEY")
    }

    // Required for App Store Guideline 3.1.2. Replace with your real URLs before submission.
    static var privacyPolicyURL: URL? {
        optionalURLString(forKey: "PRIVACY_POLICY_URL")
    }

    static var termsOfUseURL: URL? {
        optionalURLString(forKey: "TERMS_OF_USE_URL")
    }

    static var appStoreURL: URL? {
        optionalURLString(forKey: "APP_STORE_URL")
    }
}
