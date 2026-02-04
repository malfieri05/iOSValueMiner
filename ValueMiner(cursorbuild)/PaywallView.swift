//
//  PaywallView.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 2/02/26.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent

    private var accentColor: Color { ThemeColors.color(from: themeAccent) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Keep Mining Clips")
                    .font(.title2).bold()
                    .foregroundColor(.white)

                Text("You’ve reached the free limit of \(subscriptionManager.freeMonthlyLimit) clips this month.")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                VStack(spacing: 10) {
                    ForEach(subscriptionManager.products, id: \.id) { product in
                        Button {
                            Task { _ = await subscriptionManager.purchase(product) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.displayName)
                                        .foregroundColor(.white)
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(clipsSummary(for: product.id))
                                        .foregroundColor(.white.opacity(0.6))
                                        .font(.system(size: 12))
                                }
                                Spacer()
                                Text(product.displayPrice)
                                    .foregroundColor(accentColor)
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(accentColor.opacity(0.7), lineWidth: 1)
                            )
                        }
                    }
                }

                Button("Not now") {
                    dismiss()
                }
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 4)
            }
            .padding(20)
        }
        .task {
            await subscriptionManager.loadProducts()
            await subscriptionManager.refreshEntitlements()
        }
        .onChange(of: subscriptionManager.currentTier) { _, newTier in
            if newTier != .free {
                dismiss()
            }
        }
    }

    private func clipsSummary(for productId: String) -> String {
        guard let plan = subscriptionManager.plan(for: productId) else { return "Monthly plan" }
        if let limit = plan.clipsPerMonth {
            return "\(limit) clips / month"
        }
        return "Unlimited clips"
    }
}
