//
//  SearchAPI.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/23/26.
//

import Foundation

struct SearchAPI {
    static func fetchTranscript(for url: String) async throws -> String {
        let encodedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url

        var components = URLComponents(string: "https://api.supadata.ai/v1/transcript")!
        components.queryItems = [
            URLQueryItem(name: "url", value: encodedUrl),
            URLQueryItem(name: "text", value: "true"),
            URLQueryItem(name: "mode", value: "auto")
        ]

        guard let endpoint = components.url else {
            throw NSError(domain: "Supadata", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue(Config.supadataApiKey, forHTTPHeaderField: "x-api-key")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "Supadata", code: 0, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])
        }

        if http.statusCode == 202 {
            let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let jobId = decoded?["jobId"] as? String else {
                throw NSError(domain: "Supadata", code: 202, userInfo: [NSLocalizedDescriptionKey: "Missing jobId"])
            }
            return try await pollForJob(jobId: jobId)
        }

        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = decoded?["content"] as? String else {
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            throw NSError(domain: "Supadata", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: raw])
        }

        return content
    }

    private static func pollForJob(jobId: String) async throws -> String {
        let endpoint = URL(string: "https://api.supadata.ai/v1/transcript/\(jobId)")!

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue(Config.supadataApiKey, forHTTPHeaderField: "x-api-key")

        // Poll up to 12 times (~24 seconds)
        for _ in 0..<12 {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw NSError(domain: "Supadata", code: 0, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])
            }

            let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let status = decoded?["status"] as? String

            if http.statusCode == 200, status == "completed" {
                if let content = decoded?["content"] as? String {
                    return content
                }
            }

            if status == "failed" {
                let error = decoded?["error"] as? String ?? "Supadata failed"
                throw NSError(domain: "Supadata", code: 500, userInfo: [NSLocalizedDescriptionKey: error])
            }

            try await Task.sleep(nanoseconds: 2_000_000_000) // 2s
        }

        throw NSError(domain: "Supadata", code: 408, userInfo: [NSLocalizedDescriptionKey: "Transcript still processing. Try again."])
    }
}
