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

    init(auth: AuthViewModel, clipsStore: ClipsStore, subscriptionManager: SubscriptionManager) {
        self.auth = auth
        self.clipsStore = clipsStore
        self.subscriptionManager = subscriptionManager
        
        // Observe clips changes to update cache
        clipsObserver = clipsStore.$clips.sink { [weak self] clips in
            guard let self = self else { return }
            self.normalizedUrlsSet = Set(clips.map { self.normalizeUrl($0.url) })
            self.cachedMonthlyCount = nil // Invalidate monthly count cache
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
            try await enqueueClip(urlString: trimmed, userId: userId)
            urlText = ""
            setInfoThenClear(after: 2.0, "Clip queued — it'll appear when ready.")
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
            "createdAt": Timestamp(date: Date())
        ])
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
