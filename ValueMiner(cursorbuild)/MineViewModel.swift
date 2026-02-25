//
//  MineViewModel.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/25/26.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class MineViewModel: ObservableObject {
    private static let processingInfoMessage = "Clip Processing - will appear shortly."

    @Published var urlText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var showPaywall: Bool = false

    let auth: AuthViewModel
    let clipsStore: ClipsStore
    let subscriptionManager: SubscriptionManager
    
    private var normalizedUrlsSet: Set<String> = []
    private var cachedMonthlyCount: Int?
    private var cachedMonthStart: Date?
    private var clipsObserver: AnyCancellable?
    private var pendingAppearanceTargetCount: Int?

    init(auth: AuthViewModel, clipsStore: ClipsStore, subscriptionManager: SubscriptionManager) {
        self.auth = auth
        self.clipsStore = clipsStore
        self.subscriptionManager = subscriptionManager
        
        // Observe clips changes to update cache
        clipsObserver = clipsStore.$clips.sink { [weak self] clips in
            guard let self = self else { return }
            self.normalizedUrlsSet = Set(clips.map { self.normalizeUrl($0.url) })
            self.cachedMonthlyCount = nil // Invalidate monthly count cache
            if let target = self.pendingAppearanceTargetCount, clips.count >= target {
                self.pendingAppearanceTargetCount = nil
                if self.infoMessage == Self.processingInfoMessage {
                    self.infoMessage = nil
                }
            }
        }
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
        if normalizedUrlsSet.contains(normalized) {
            infoMessage = "Clip previously mined."
            return
        }

        #if DEBUG
        let isWhitelistedUser = auth.user?.email?.lowercased() == "malfieri05@gmail.com"
        #else
        let isWhitelistedUser = false
        #endif
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
            let expectedClipCount = clipsStore.clips.count + 1
            try await enqueueClip(urlString: trimmed, userId: userId)
            schedulePostEnqueueRefresh(userId: userId, expectedClipCount: expectedClipCount)
            pendingAppearanceTargetCount = max(pendingAppearanceTargetCount ?? 0, expectedClipCount)
            urlText = ""
            infoMessage = Self.processingInfoMessage
        } catch {
            setErrorThenClear(after: 2.2, error.localizedDescription)
        }
    }

    /// Same as share extension: write to clipQueue for backend to process. Keeps in-app paste as fast as share.
    private func enqueueClip(urlString: String, userId: String) async throws {
        let db = Firestore.firestore()
        let doc = db.collection("clipQueue").document()
        try await doc.setData([
            "userId": userId,
            "url": urlString,
            "status": "queued",
            "createdAt": Timestamp(date: Date()),
            "preferredTranscriptLang": Self.preferredTranscriptLanguageCode()
        ])
    }

    /// ISO 639-1 code for transcript language (e.g. "en"). Backend passes this to Supadata and uses it as translation target when needed.
    private static func preferredTranscriptLanguageCode() -> String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    private func setInfoThenClear(after seconds: TimeInterval, _ message: String) {
        infoMessage = message
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if infoMessage == message {
                infoMessage = nil
            }
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

    func showTransientError(_ message: String, duration: TimeInterval = 2.2) {
        setErrorThenClear(after: duration, message)
    }

    private func schedulePostEnqueueRefresh(userId: String, expectedClipCount: Int) {
        Task { [weak self] in
            guard let self else { return }

            // Fallback refresh: if backend processing finished but listener did not surface
            // the new clip yet, force a lightweight re-listen.
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard self.auth.userId == userId else { return }
            if self.clipsStore.clips.count < expectedClipCount {
                self.clipsStore.startListening(userId: userId)
            }

            // One additional retry for slower queue processing.
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            guard self.auth.userId == userId else { return }
            if self.clipsStore.clips.count < expectedClipCount {
                self.clipsStore.startListening(userId: userId)
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
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        
        // Check if cache is still valid (same month)
        if let cached = cachedMonthlyCount,
           let cachedStart = cachedMonthStart,
           calendar.isDate(cachedStart, equalTo: startOfMonth, toGranularity: .month) {
            return cached
        }
        
        // Calculate and cache
        let count = clipsStore.clips.filter { $0.createdAt >= startOfMonth }.count
        cachedMonthlyCount = count
        cachedMonthStart = startOfMonth
        return count
    }
}
