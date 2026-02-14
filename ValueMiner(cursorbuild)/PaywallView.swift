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
    @AppStorage(ThemeColors.backgroundKey) private var themeBackground = ThemeColors.defaultBackground
    @State private var productsLoadFailed = false

    private var accentColor: Color { ThemeColors.color(from: themeAccent) }
    private var primaryText: Color { ThemeColors.primaryText(from: themeBackground) }
    private var backgroundColor: Color { ThemeColors.background(from: themeBackground) }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            if #available(iOS 17.0, *) {
                subscriptionStoreContent
            } else {
                legacyPaywallContent
            }
        }
        .task {
            await subscriptionManager.loadProducts()
            await subscriptionManager.refreshEntitlements()
            if subscriptionManager.products.isEmpty {
                productsLoadFailed = true
            }
        }
        .onChange(of: subscriptionManager.currentTier) { _, newTier in
            if newTier != .free {
                dismiss()
            }
        }
        .preferredColorScheme(themeBackground == "white" ? .light : .dark)
    }

    @available(iOS 17.0, *)
    @ViewBuilder
    private var subscriptionStoreContent: some View {
        subscriptionStoreViewWithPolicyLinks
    }

    @available(iOS 17.0, *)
    @ViewBuilder
    private var subscriptionStoreViewWithPolicyLinks: some View {
        if let privacy = Config.privacyPolicyURL, let terms = Config.termsOfUseURL {
            SubscriptionStoreView(productIDs: SubscriptionManager.subscriptionProductIDs) { paywallHeader }
                .subscriptionStoreButtonLabel(.multiline)
                .storeButton(.visible, for: .restorePurchases)
                .subscriptionStorePolicyDestination(url: privacy, for: .privacyPolicy)
                .subscriptionStorePolicyDestination(url: terms, for: .termsOfService)
        } else if let privacy = Config.privacyPolicyURL {
            SubscriptionStoreView(productIDs: SubscriptionManager.subscriptionProductIDs) { paywallHeader }
                .subscriptionStoreButtonLabel(.multiline)
                .storeButton(.visible, for: .restorePurchases)
                .subscriptionStorePolicyDestination(url: privacy, for: .privacyPolicy)
        } else if let terms = Config.termsOfUseURL {
            SubscriptionStoreView(productIDs: SubscriptionManager.subscriptionProductIDs) { paywallHeader }
                .subscriptionStoreButtonLabel(.multiline)
                .storeButton(.visible, for: .restorePurchases)
                .subscriptionStorePolicyDestination(url: terms, for: .termsOfService)
        } else {
            SubscriptionStoreView(productIDs: SubscriptionManager.subscriptionProductIDs) { paywallHeader }
                .subscriptionStoreButtonLabel(.multiline)
                .storeButton(.visible, for: .restorePurchases)
        }
    }

    private var paywallHeader: some View {
        Text("You've reached your monthly usage limit.")
            .font(.title2).bold()
            .foregroundColor(primaryText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.bottom, 2)
    }

    /// Fallback when SubscriptionStoreView is not available (pre–iOS 17).
    private var legacyPaywallContent: some View {
        VStack(spacing: 18) {
            paywallHeader

            if Config.privacyPolicyURL != nil || Config.termsOfUseURL != nil {
                HStack(spacing: 16) {
                    if let url = Config.termsOfUseURL {
                        Link("Terms of Use", destination: url)
                            .font(.caption)
                            .foregroundColor(accentColor)
                    }
                    if let url = Config.privacyPolicyURL {
                        Link("Privacy Policy", destination: url)
                            .font(.caption)
                            .foregroundColor(accentColor)
                    }
                }
            }

            if subscriptionManager.products.isEmpty && !productsLoadFailed {
                ProgressView()
                    .tint(primaryText)
                    .padding()
                Text("Loading subscription options…")
                    .font(.subheadline)
                    .foregroundColor(primaryText.opacity(0.7))
            } else if subscriptionManager.products.isEmpty {
                VStack(spacing: 12) {
                    Text("Subscription options couldn’t be loaded.")
                        .font(.subheadline)
                        .foregroundColor(primaryText.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        productsLoadFailed = false
                        Task {
                            await subscriptionManager.loadProducts()
                            await subscriptionManager.refreshEntitlements()
                        }
                    }
                    .foregroundColor(accentColor)
                }
                .padding()
            } else {
                VStack(spacing: 10) {
                    ForEach(subscriptionManager.products, id: \.id) { product in
                        Button {
                            Task { _ = await subscriptionManager.purchase(product) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.displayName)
                                        .foregroundColor(primaryText)
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(clipsSummary(for: product.id))
                                        .foregroundColor(primaryText.opacity(0.6))
                                        .font(.system(size: 12))
                                }
                                Spacer()
                                Text(product.displayPrice)
                                    .foregroundColor(accentColor)
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .padding(14)
                            .background(primaryText.opacity(0.06))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(accentColor.opacity(0.7), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
        .padding(20)
    }

    private func clipsSummary(for productId: String) -> String {
        guard let plan = subscriptionManager.plan(for: productId) else { return "Monthly plan" }
        if let limit = plan.clipsPerMonth {
            return "\(limit) clips / month"
        }
        return "450 clips / month"
    }
}

