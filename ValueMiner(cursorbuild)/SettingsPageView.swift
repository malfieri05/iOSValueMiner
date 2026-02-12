//
//  SettingsPageView.swift
//  ValueMiner(cursorbuild)
//
//  Settings page with SUPPORT, ABOUT, Subscription, Language, Delete Account, and Sign out.
//

import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore

struct SettingsPageView: View {
    let onSignOut: () -> Void
    let subscriptionManager: SubscriptionManager

    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
    @AppStorage(ThemeColors.backgroundKey) private var themeBackground = ThemeColors.defaultBackground
    @AppStorage("transcriptLanguage") private var transcriptLanguage = "en"
    @State private var showOnboarding = false
    @State private var showLanguagePicker = false
    @State private var showPaywallPreview = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountStatus: String?

    private var accentColor: Color { ThemeColors.color(from: themeAccent) }
    private var primaryText: Color { ThemeColors.primaryText(from: themeBackground) }
    private var backgroundColor: Color { ThemeColors.background(from: themeBackground) }

    private var userId: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        List {
                Section {
                    HStack {
                        Text("Current plan:")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(primaryText)
                        Spacer()
                        Text(currentPlanLabel)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(primaryText.opacity(0.8))
                    }
                    .listRowBackground(primaryText.opacity(0.06))

                    settingsRow(icon: "creditcard.fill", title: "Manage Subscription") {
                        openManageSubscriptions()
                    }
                    settingsRow(icon: "lock.fill", title: "Preview Paywall") {
                        showPaywallPreview = true
                    }
                } header: {
                    Text("SUBSCRIPTION")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(primaryText.opacity(0.5))
                }
                .listRowBackground(primaryText.opacity(0.06))
                .listRowSeparatorTint(primaryText.opacity(0.15))

                Section {
                    settingsRow(icon: "book.fill", title: "View Onboarding", subtitle: "Learn how to use ScrollMiner") {
                        showOnboarding = true
                    }
                    settingsRow(icon: "bubble.left.fill", title: "Send feedback") {
                        openEmail(subject: "ScrollMiner Feedback")
                    }
                    settingsRow(icon: "ladybug.fill", title: "Report a bug") {
                        openEmail(subject: "ScrollMiner Bug Report")
                    }
                } header: {
                    Text("SUPPORT")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(primaryText.opacity(0.5))
                }
                .listRowBackground(primaryText.opacity(0.06))
                .listRowSeparatorTint(primaryText.opacity(0.15))

                Section {
                    if let url = Config.privacyPolicyURL {
                        Link(destination: url) {
                            settingsRowContent(icon: "lock.shield.fill", title: "Privacy Policy")
                        }
                    }
                    if let url = Config.termsOfUseURL {
                        Link(destination: url) {
                            settingsRowContent(icon: "doc.text.fill", title: "Terms of Service")
                        }
                    }
                } header: {
                    Text("ABOUT")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(primaryText.opacity(0.5))
                }
                .listRowBackground(primaryText.opacity(0.06))
                .listRowSeparatorTint(primaryText.opacity(0.15))

                Section {
                    HStack {
                        Text("Transcription language:")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(primaryText)
                        Spacer()
                        Text(languageName(for: transcriptLanguage))
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(primaryText.opacity(0.8))
                    }
                    .listRowBackground(primaryText.opacity(0.06))

                    settingsRow(icon: "globe", title: "Choose Language") {
                        showLanguagePicker = true
                    }
                } header: {
                    Text("LANGUAGE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(primaryText.opacity(0.5))
                }
                .listRowBackground(primaryText.opacity(0.06))
                .listRowSeparatorTint(primaryText.opacity(0.15))

                Section {
                    Button(role: .destructive, action: { showDeleteAccountConfirm = true }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                                .frame(width: 28, alignment: .center)
                            Text(isDeletingAccount ? "Deleting..." : "Delete Account")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(isDeletingAccount)
                    .listRowBackground(primaryText.opacity(0.06))

                    if let status = deleteAccountStatus {
                        Text(status)
                            .font(.footnote)
                            .foregroundColor(primaryText.opacity(0.6))
                            .listRowBackground(primaryText.opacity(0.06))
                    }
                } header: {
                    Text("ACCOUNT")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(primaryText.opacity(0.5))
                }
                .listRowSeparatorTint(primaryText.opacity(0.15))
                .alert("Delete account?", isPresented: $showDeleteAccountConfirm) {
                    Button("Delete", role: .destructive) { deleteAccount() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete your account and all saved clips.")
                }

                Section {
                    Button(action: onSignOut) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(accentColor)
                                .frame(width: 28, alignment: .center)
                            Text("Sign out")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(primaryText)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(primaryText.opacity(0.06))
                }
                .listRowSeparatorTint(primaryText.opacity(0.15))
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .background(backgroundColor)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(backgroundColor, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showOnboarding) {
            ShareSheetOnboardingView(onDismiss: {
                showOnboarding = false
            }, allowsEarlyDismiss: true)
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(
                selectedLanguage: $transcriptLanguage,
                options: languageOptions
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPaywallPreview) {
            PaywallView(subscriptionManager: subscriptionManager)
                .presentationDetents([.fraction(0.9)])
        }
    }

    private var currentPlanLabel: String {
        switch subscriptionManager.currentTier {
        case .free: return "Free"
        case .starter: return "Starter"
        case .silver: return "Silver"
        case .gold: return "Gold"
        }
    }

    private func openManageSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }

    private var languageOptions: [(code: String, name: String)] {
        [
            ("en", "English"),
            ("es", "Spanish"),
            ("fr", "French"),
            ("de", "German"),
            ("it", "Italian"),
            ("pt", "Portuguese"),
            ("nl", "Dutch"),
            ("sv", "Swedish"),
            ("da", "Danish"),
            ("no", "Norwegian"),
            ("fi", "Finnish"),
            ("pl", "Polish"),
            ("cs", "Czech"),
            ("tr", "Turkish"),
            ("ru", "Russian"),
            ("uk", "Ukrainian"),
            ("ar", "Arabic"),
            ("he", "Hebrew"),
            ("hi", "Hindi"),
            ("id", "Indonesian"),
            ("ms", "Malay"),
            ("th", "Thai"),
            ("vi", "Vietnamese"),
            ("ja", "Japanese"),
            ("ko", "Korean"),
            ("zh", "Chinese"),
            ("el", "Greek")
        ]
    }

    private func languageName(for code: String) -> String {
        languageOptions.first(where: { $0.code == code })?.name ?? "English"
    }

    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            deleteAccountStatus = "No signed-in user."
            return
        }
        isDeletingAccount = true
        deleteAccountStatus = nil
        Task {
            do {
                if let uid = userId {
                    try await deleteUserData(userId: uid)
                }
                try await user.delete()
                deleteAccountStatus = "Account deleted."
                onSignOut()
            } catch {
                let nsError = error as NSError
                if nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    deleteAccountStatus = "Please sign out and sign back in, then try again."
                } else {
                    deleteAccountStatus = "Failed to delete account."
                }
                print("Delete account error:", error)
            }
            isDeletingAccount = false
        }
    }

    private func deleteUserData(userId: String) async throws {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        let clipsSnapshot = try await userRef.collection("clips").getDocuments()
        for doc in clipsSnapshot.documents {
            try await doc.reference.delete()
        }
        let categoriesSnapshot = try await userRef.collection("categories").getDocuments()
        for doc in categoriesSnapshot.documents {
            try await doc.reference.delete()
        }
        try await userRef.delete()
    }

    private func settingsRow(icon: String, title: String, subtitle: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            settingsRowContent(icon: icon, title: title, subtitle: subtitle)
        }
    }

    private func settingsRowContent(icon: String, title: String, subtitle: String? = nil) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(accentColor)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(primaryText)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(primaryText.opacity(0.6))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(primaryText.opacity(0.4))
        }
        .padding(.vertical, 4)
    }

    private func openEmail(subject: String) {
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        guard let url = URL(string: "mailto:admin@valueminer.org?subject=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }
}
