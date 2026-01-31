//
//  CategoriesStore.swift
//  ValueMiner(cursorbuild)
//
//  Created by Assistant on 1/26/26.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class CategoriesStore: ObservableObject {
    @Published var defaultCategories: [String] = [
        "All",
        "Health",
        "Business",
        "Funny",
        "Motivation",
        "Science",
        "Other"
    ]

    @Published var customCategories: [String] = []
    @Published var customOrder: [String]? = nil

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var orderListener: ListenerRegistration?

    func startListening(userId: String) {
        stopListening()
        
        // Listen to custom categories
        listener = db
            .collection("users")
            .document(userId)
            .collection("categories")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    print("Categories listen error:", error)
                    return
                }
                let docs = snapshot?.documents ?? []
                self.customCategories = docs.compactMap { $0.data()["name"] as? String }
            }
        
        // Listen to custom order
        orderListener = db
            .collection("users")
            .document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    print("Order listen error:", error)
                    return
                }
                if let data = snapshot?.data(),
                   let order = data["categoryOrder"] as? [String] {
                    self.customOrder = order
                } else {
                    self.customOrder = nil
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        orderListener?.remove()
        orderListener = nil
        customCategories = []
        customOrder = nil
    }

    func addCategory(userId: String, name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Prevent duplicates against default and custom
        let lower = trimmed.lowercased()
        let allExisting = Set((defaultCategories + customCategories).map { $0.lowercased() })
        guard !allExisting.contains(lower) else { return }

        let ref = db
            .collection("users")
            .document(userId)
            .collection("categories")
            .document()

        try await ref.setData(["name": trimmed])
    }
    
    func saveCustomOrder(userId: String, order: [String]) async throws {
        try await db
            .collection("users")
            .document(userId)
            .updateData(["categoryOrder": order])
    }
}
