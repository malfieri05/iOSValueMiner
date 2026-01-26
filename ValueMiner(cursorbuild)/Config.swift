//
//  Config.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/23/26.
//

import Foundation

enum Config {
    static var searchApiKey: String {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let key = dict["SEARCH_API_KEY"] as? String,
              !key.isEmpty
        else {
            fatalError("SEARCH_API_KEY missing in Secrets.plist")
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var supadataApiKey: String {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let key = dict["SUPADATA_API_KEY"] as? String,
              !key.isEmpty
        else {
            fatalError("SUPADATA_API_KEY missing in Secrets.plist")
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
