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
}
