//
//  SubscriptionManager.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 2/02/26.
//

import Foundation
import Combine
import StoreKit

@MainActor
final class SubscriptionManager: ObservableObject {
    enum Tier: Int, CaseIterable, Comparable {
        case free = 0
        case starter
        case silver
        case gold

        static func < (lhs: Tier, rhs: Tier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    struct Plan: Identifiable {
        let id: String
        let tier: Tier
        let displayName: String
        let clipsPerMonth: Int?
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var activeProductIds: Set<String> = []
    @Published private(set) var currentTier: Tier = .free

    private let plans: [Plan] = [
        Plan(id: "scrollmine.starter.monthly", tier: .starter, displayName: "Starter", clipsPerMonth: 50),
        Plan(id: "scrollmine.silver.monthly", tier: .silver, displayName: "Silver", clipsPerMonth: 200),
        Plan(id: "scrollmine.gold.monthly", tier: .gold, displayName: "Gold", clipsPerMonth: nil)
    ]

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
            await self?.observeTransactions()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var freeMonthlyLimit: Int { 5 }

    func plan(for productId: String) -> Plan? {
        plans.first { $0.id == productId }
    }

    func clipsLimit(for tier: Tier) -> Int? {
        switch tier {
        case .free: return freeMonthlyLimit
        case .starter: return 50
        case .silver: return 200
        case .gold: return nil
        }
    }

    func canMine(currentMonthCount: Int) -> Bool {
        if let limit = clipsLimit(for: currentTier) {
            return currentMonthCount < limit
        }
        return true
    }

    func loadProducts() async {
        do {
            let ids = plans.map { $0.id }
            let storeProducts = try await Product.products(for: ids)
            products = storeProducts.sorted { lhs, rhs in
                tier(for: lhs.id).rawValue < tier(for: rhs.id).rawValue
            }
        } catch {
            print("StoreKit products fetch error:", error)
            products = []
        }
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("StoreKit purchase error:", error)
            return false
        }
    }

    func refreshEntitlements() async {
        var active: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if plans.contains(where: { $0.id == transaction.productID }) {
                active.insert(transaction.productID)
            }
        }

        activeProductIds = active
        currentTier = highestTier(for: active)
    }

    private func observeTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    private func highestTier(for active: Set<String>) -> Tier {
        let tiers = active.compactMap { plan(for: $0)?.tier }
        return tiers.max() ?? .free
    }

    private func tier(for productId: String) -> Tier {
        plan(for: productId)?.tier ?? .free
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified(_, let error): throw error
        }
    }
}
