//
//  ClipsStore.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/24/26.
//

import Foundation
import Combine
import FirebaseFirestore

struct Clip: Identifiable, Hashable {
    let id: String
    let url: String
    let transcript: String
    let category: String
    let platform: String
    let createdAt: Date
    var personalNotes: String?
}

@MainActor
final class ClipsStore: ObservableObject {
    @Published var clips: [Clip] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var clipsById: [String: Clip] = [:]

    func startListening(userId: String) {
        stopListening(clearData: false)

        listener = db
            .collection("users")
            .document(userId)
            .collection("clips")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    print("Firestore listen error:", error)
                    return
                }

                let docs = snapshot?.documents ?? []
                var newClips: [Clip] = []
                var newClipsById: [String: Clip] = [:]
                
                for doc in docs {
                    let data = doc.data()
                    guard
                        let url = data["url"] as? String,
                        let transcript = data["transcript"] as? String,
                        let category = data["category"] as? String,
                        let platform = data["platform"] as? String,
                        let ts = data["createdAt"] as? Timestamp
                    else { continue }

                    let personalNotes = data["personalNotes"] as? String
                    let clip = Clip(
                        id: doc.documentID,
                        url: url,
                        transcript: transcript,
                        category: category,
                        platform: platform,
                        createdAt: ts.dateValue(),
                        personalNotes: personalNotes
                    )
                    newClips.append(clip)
                    newClipsById[doc.documentID] = clip
                }
                
                // Only update if changed to avoid unnecessary UI refreshes
                if newClips != self.clips {
                    self.clips = newClips
                    self.clipsById = newClipsById
                }
            }
    }

    func stopListening(clearData: Bool = true) {
        listener?.remove()
        listener = nil
        if clearData {
            clips = []
            clipsById = [:]
        }
    }

    func addClip(
        userId: String,
        url: String,
        transcript: String,
        platform: String,
        category: String = "Other"
    ) async throws {
        let ref = db
            .collection("users")
            .document(userId)
            .collection("clips")
            .document()

        let data: [String: Any] = [
            "url": url,
            "transcript": transcript,
            "category": category,
            "platform": platform,
            "createdAt": Timestamp(date: Date())
        ]

        try await ref.setData(data)
    }

    func updateCategory(userId: String, clipId: String, category: String) async throws {
        try await db
            .collection("users")
            .document(userId)
            .collection("clips")
            .document(clipId)
            .updateData(["category": category])
    }

    func updateNotes(userId: String, clipId: String, notes: String) async throws {
        try await db
            .collection("users")
            .document(userId)
            .collection("clips")
            .document(clipId)
            .updateData(["personalNotes": notes])
        // Update local state immediately so UI reflects change without waiting for listener
        if let idx = clips.firstIndex(where: { $0.id == clipId }) {
            var updated = clips[idx]
            updated.personalNotes = notes.isEmpty ? nil : notes
            clips[idx] = updated
        }
    }

    func clip(withId id: String) -> Clip? {
        clipsById[id]
    }

    func deleteClip(userId: String, clipId: String) async throws {
        try await db
            .collection("users")
            .document(userId)
            .collection("clips")
            .document(clipId)
            .delete()
    }

    // MARK: - Book Equivalent Tracking

    /// Words required for one "book equivalent" of core knowledge
    /// Based on research: avg nonfiction book ~50,000 words, ~10% is core actionable content
    static let wordsPerBookEquivalent: Int = 5000

    /// Calculate total transcript words for a given category
    func wordCount(for category: String) -> Int {
        let relevantClips = category == "All"
            ? clips
            : clips.filter { $0.category == category }

        return relevantClips.reduce(0) { total, clip in
            total + clip.transcript.split(whereSeparator: { $0.isWhitespace }).count
        }
    }

    /// Calculate book equivalents for a category (as a Double for partial progress)
    func bookEquivalents(for category: String) -> Double {
        let words = wordCount(for: category)
        return Double(words) / Double(Self.wordsPerBookEquivalent)
    }

    /// Get progress toward next book equivalent (0.0 - 1.0)
    func progressToNextBook(for category: String) -> Double {
        let equivalents = bookEquivalents(for: category)
        return equivalents.truncatingRemainder(dividingBy: 1.0)
    }

    /// Get completed book count for a category
    func completedBooks(for category: String) -> Int {
        return Int(bookEquivalents(for: category))
    }

    /// Get clip count for a category
    func clipCount(for category: String) -> Int {
        if category == "All" {
            return clips.count
        }
        return clips.filter { $0.category == category }.count
    }

    /// Check which milestone (0.25, 0.5, 0.75, 1.0) was just crossed
    func checkMilestone(for category: String, previousWordCount: Int) -> Double? {
        let prevProgress = Double(previousWordCount % Self.wordsPerBookEquivalent) / Double(Self.wordsPerBookEquivalent)
        let currentProgress = progressToNextBook(for: category)
        let prevBooks = previousWordCount / Self.wordsPerBookEquivalent
        let currentBooks = completedBooks(for: category)

        // Check if we completed a full book
        if currentBooks > prevBooks {
            return 1.0
        }

        // Check milestone crossings within the same book
        let milestones: [Double] = [0.25, 0.5, 0.75]
        for milestone in milestones {
            if prevProgress < milestone && currentProgress >= milestone {
                return milestone
            }
        }
        return nil
    }
}
