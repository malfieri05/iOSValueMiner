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
    @Published var removedDefaultCategories: Set<String> = []

    private let db = Firestore.firestore()
    private let removedDefaultsKey = "removedDefaultCategories"

    init() {
        if let saved = UserDefaults.standard.array(forKey: removedDefaultsKey) as? [String] {
            removedDefaultCategories = Set(saved)
        }
    }

    /// Default categories the user still has (All and Other are always included)
    var activeDefaultCategories: [String] {
        defaultCategories.filter { name in
            let lower = name.lowercased()
            if lower == "all" || lower == "other" { return true }
            return !removedDefaultCategories.contains(where: { $0.lowercased() == lower })
        }
    }

    func removeDefaultCategory(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let lower = trimmed.lowercased()
        guard lower != "all", lower != "other" else { return }
        removedDefaultCategories.insert(trimmed)
        UserDefaults.standard.set(Array(removedDefaultCategories), forKey: removedDefaultsKey)
    }

    private var listener: ListenerRegistration?
    private var orderListener: ListenerRegistration?

    func startListening(userId: String) {
        stopListening()
        
        // Listen to custom categories (newest first so new categories appear after "All")
        listener = db
            .collection("users")
            .document(userId)
            .collection("categories")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    print("Categories listen error:", error)
                    return
                }
                let docs = snapshot?.documents ?? []
                // Sort: docs with createdAt first (newest first), then docs without (e.g. legacy)
                let sorted = docs.sorted { d1, d2 in
                    let t1 = d1.data()["createdAt"] as? Timestamp
                    let t2 = d2.data()["createdAt"] as? Timestamp
                    if let t1, let t2 { return t1.dateValue() > t2.dateValue() }
                    if t1 != nil { return true }
                    if t2 != nil { return false }
                    return (d1.data()["name"] as? String ?? "") < (d2.data()["name"] as? String ?? "")
                }
                self.customCategories = sorted.compactMap { $0.data()["name"] as? String }
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
        // Prevent duplicates against active defaults and custom
        let lower = trimmed.lowercased()
        let allExisting = Set((activeDefaultCategories + customCategories).map { $0.lowercased() })
        guard !allExisting.contains(lower) else { return }

        let ref = db
            .collection("users")
            .document(userId)
            .collection("categories")
            .document()

        try await ref.setData([
            "name": trimmed,
            "createdAt": Timestamp(date: Date())
        ])
    }
    
    func saveCustomOrder(userId: String, order: [String]) async throws {
        try await db
            .collection("users")
            .document(userId)
            .updateData(["categoryOrder": order])
    }
}
