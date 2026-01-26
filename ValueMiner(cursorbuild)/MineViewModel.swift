//
//  MineViewModel.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/25/26.
//

import Foundation
import Combine

@MainActor
final class MineViewModel: ObservableObject {
    @Published var urlText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    let auth: AuthViewModel
    let clipsStore: ClipsStore

    init(auth: AuthViewModel, clipsStore: ClipsStore) {
        self.auth = auth
        self.clipsStore = clipsStore
    }

    func mine() async {
        errorMessage = nil
        infoMessage = nil

        guard let userId = auth.userId else {
            errorMessage = "Please sign in first."
            return
        }

        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please paste a valid URL."
            return
        }

        let normalized = normalizeUrl(trimmed)
        if clipsStore.clips.contains(where: { normalizeUrl($0.url) == normalized }) {
            infoMessage = "Clip previously mined."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let transcript = try await SearchAPI.fetchTranscript(for: trimmed)
            let platform = detectPlatform(from: trimmed)
            try await clipsStore.addClip(
                userId: userId,
                url: trimmed,
                transcript: transcript,
                platform: platform,
                category: "Other"
            )
            urlText = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func normalizeUrl(_ url: String) -> String {
        url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func detectPlatform(from url: String) -> String {
        let lower = url.lowercased()
        if lower.contains("youtube.com") || lower.contains("youtu.be") { return "YouTube" }
        if lower.contains("tiktok.com") { return "TikTok" }
        if lower.contains("instagram.com") { return "Instagram" }
        if lower.contains("x.com") || lower.contains("twitter.com") { return "X" }
        if lower.contains("facebook.com") { return "Facebook" }
        return "Other"
    }
}
