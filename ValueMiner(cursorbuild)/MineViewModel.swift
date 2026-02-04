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
    @Published var showPaywall: Bool = false

    let auth: AuthViewModel
    let clipsStore: ClipsStore
    let subscriptionManager: SubscriptionManager

    init(auth: AuthViewModel, clipsStore: ClipsStore, subscriptionManager: SubscriptionManager) {
        self.auth = auth
        self.clipsStore = clipsStore
        self.subscriptionManager = subscriptionManager
    }

    func mine() async {
        errorMessage = nil
        infoMessage = nil

        guard let userId = auth.userId else {
            setErrorThenClear(after: 2.2, "Please sign in first.")
            return
        }

        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            setErrorThenClear(after: 2.2, "Please paste a valid URL.")
            return
        }

        let normalized = normalizeUrl(trimmed)
        if clipsStore.clips.contains(where: { normalizeUrl($0.url) == normalized }) {
            infoMessage = "Clip previously mined."
            return
        }

        let isWhitelistedUser = auth.user?.email?.lowercased() == "malfieri05@gmail.com"
        if !isWhitelistedUser {
            let monthlyCount = currentMonthClipCount()
            if !subscriptionManager.canMine(currentMonthCount: monthlyCount) {
                infoMessage = "Monthly clip limit reached."
                showPaywall = true
                return
            }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let lang = UserDefaults.standard.string(forKey: "transcriptLanguage") ?? "en"
            let transcript = try await SearchAPI.fetchTranscript(for: trimmed, lang: lang)
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
            setErrorThenClear(after: 2.2, error.localizedDescription)
        }
    }

    private func setErrorThenClear(after seconds: TimeInterval, _ message: String) {
        errorMessage = message
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if errorMessage == message {
                errorMessage = nil
            }
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

    private func currentMonthClipCount() -> Int {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        return clipsStore.clips.filter { $0.createdAt >= startOfMonth }.count
    }
}
