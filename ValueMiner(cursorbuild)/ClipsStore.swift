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
}

@MainActor
final class ClipsStore: ObservableObject {
    @Published var clips: [Clip] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening(userId: String) {
        stopListening()

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
                self.clips = docs.compactMap { doc in
                    let data = doc.data()
                    guard
                        let url = data["url"] as? String,
                        let transcript = data["transcript"] as? String,
                        let category = data["category"] as? String,
                        let platform = data["platform"] as? String,
                        let ts = data["createdAt"] as? Timestamp
                    else { return nil }

                    return Clip(
                        id: doc.documentID,
                        url: url,
                        transcript: transcript,
                        category: category,
                        platform: platform,
                        createdAt: ts.dateValue()
                    )
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        clips = []
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

    func deleteClip(userId: String, clipId: String) async throws {
        try await db
            .collection("users")
            .document(userId)
            .collection("clips")
            .document(clipId)
            .delete()
    }
}
