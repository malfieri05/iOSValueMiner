//
//  ContentView.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/23/26.
//

import SwiftUI
import Combine
import UIKit
import AuthenticationServices
import StoreKit
import FirebaseAuth

struct ContentView: View {
    private struct CategoryCacheInputs: Equatable {
        let custom: [String]
        let defaults: [String]
        let removed: Set<String>
    }

    @StateObject private var auth = AuthViewModel()
    @StateObject private var clipsStore = ClipsStore()
    @StateObject private var categoriesStore = CategoriesStore()
    @StateObject private var vm: MineViewModel
    @StateObject private var subscriptionManager: SubscriptionManager

    @State private var selectedClip: Clip?
    @State private var selectedClipNumber: Int?
    @State private var isLoginMode = false
    @State private var selectedTab = 0
    @State private var mineTabResetCounter = 0
    @State private var appleNonce: String?
    @State private var cachedCombinedCategories: [String] = []
    @State private var cachedSelectedClip: Clip?
    @State private var didShowShareSheetIntroForCurrentUser = false
    @AppStorage("didRequestReviewAfterThreeClips") private var didRequestReviewAfterThreeClips = false
    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
    @AppStorage(ThemeColors.backgroundKey) private var themeBackground = ThemeColors.defaultBackground
    @Environment(\.requestReview) private var requestReview

    init() {
        let auth = AuthViewModel()
        let store = ClipsStore()
        let categories = CategoriesStore()
        let subscriptions = SubscriptionManager()
        _auth = StateObject(wrappedValue: auth)
        _clipsStore = StateObject(wrappedValue: store)
        _categoriesStore = StateObject(wrappedValue: categories)
        _subscriptionManager = StateObject(wrappedValue: subscriptions)
        _vm = StateObject(wrappedValue: MineViewModel(auth: auth, clipsStore: store, subscriptionManager: subscriptions))
    }
    
    private let authFormMaxWidth: CGFloat = 360
    private var accentColor: Color { ThemeColors.color(from: themeAccent) }
    private var primaryText: Color { ThemeColors.primaryText(from: themeBackground) }
    private var backgroundColor: Color { ThemeColors.background(from: themeBackground) }
    private var categoryCacheInputs: CategoryCacheInputs {
        CategoryCacheInputs(
            custom: categoriesStore.customCategories,
            defaults: categoriesStore.defaultCategories,
            removed: categoriesStore.removedDefaultCategories
        )
    }
    
    // Cached app icon - computed once
    private static let cachedAppIconName: String? = {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String],
            let name = files.last
        else { return nil }
        return name
    }()
    
    private static let cachedAppIconUIImage: UIImage? = {
        if let name = cachedAppIconName, let img = UIImage(named: name) {
            return img
        }
        return UIImage(named: "AppIcon")
    }()

    var body: some View {
        Group {
            if auth.user != nil {
                if auth.requiresEmailVerification {
                    VerifyEmailView(auth: auth)
                } else if !didShowShareSheetIntroForCurrentUser {
                    ShareSheetOnboardingView(onDismiss: {
                        setDidShowShareSheetIntro(true, for: auth.userId)
                        didShowShareSheetIntroForCurrentUser = true
                    }, allowsEarlyDismiss: false)
                } else {
                    TabView(selection: $selectedTab) {
                        DashboardView(
                            clips: clipsStore.clips,
                            clipsStore: clipsStore,
                            vm: vm,
                            selectedClip: $selectedClip,
                            selectedClipNumber: $selectedClipNumber,
                            mineTabResetCounter: $mineTabResetCounter,
                            categoriesStore: categoriesStore,
                            userId: auth.userId,
                            onSelectCategory: { clip, category in
                                Task { await updateCategory(clipId: clip.id, category: category) }
                            }
                        )
                        .tabItem { tabItem(systemImage: "bolt.fill") }
                        .tag(0)

                        KnowledgeProgressView(
                            clipsStore: clipsStore,
                            categoriesStore: categoriesStore,
                            userId: auth.userId
                        )
                        .tabItem { tabItem(systemImage: "books.vertical.fill") }
                        .tag(1)

                        NavigationStack {
                            SettingsView(
                                onSignOut: {
                                    auth.signOut()
                                },
                                subscriptionManager: subscriptionManager
                            )
                        }
                        .tabItem { tabItem(systemImage: "scroll.fill") }
                        .tag(2)
                    }
                    .background(
                        TabBarHapticsObserver { index in
                            lightHaptic()
                            if index == 0 {
                                mineTabResetCounter += 1
                            }
                        }
                    )
                    .overlay(
                        ZStack {
                            if selectedClip != nil {
                                Color.black.opacity(0.35)
                                    .ignoresSafeArea()
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                            selectedClip = nil
                                            selectedClipNumber = nil
                                            cachedSelectedClip = nil
                                        }
                                    }
                                    .transition(.opacity)
                                    .zIndex(9)
                            }
                            if let selected = selectedClip {
                                let clip: Clip = {
                                    if let cached = cachedSelectedClip, cached.id == selected.id {
                                        return cached
                                    }
                                    let found = clipsStore.clip(withId: selected.id) ?? selected
                                    cachedSelectedClip = found
                                    return found
                                }()
                                ClipDetailModal(
                                    clip: clip,
                                    clipNumber: selectedClipNumber,
                                    categories: cachedCombinedCategories,
                                    onSelectCategory: { category in
                                        Task { await updateCategory(clipId: clip.id, category: category) }
                                    },
                                    onDismiss: {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                            selectedClip = nil
                                            selectedClipNumber = nil
                                            cachedSelectedClip = nil
                                        }
                                    },
                                    onSaveNotes: { notes in
                                        Task { await updateNotes(clipId: clip.id, notes: notes) }
                                    },
                                    onDelete: {
                                        guard let uid = auth.userId else { return }
                                        Task {
                                            do {
                                                try await clipsStore.deleteClip(userId: uid, clipId: clip.id)
                                            } catch {
                                                auth.showError("Couldn't delete clip. Please try again.")
                                            }
                                            await MainActor.run {
                                                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                                    selectedClip = nil
                                                    selectedClipNumber = nil
                                                    cachedSelectedClip = nil
                                                }
                                            }
                                        }
                                    }
                                )
                                .transition(.scale(scale: 0.96).combined(with: .opacity))
                                .zIndex(10)
                            }
                        }
                        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: selectedClip != nil)
                    )
                }
            } else {
                authView
            }
        }
        .onChange(of: auth.userId) { _, newValue in
            if let userId = newValue {
                clipsStore.startListening(userId: userId)
                categoriesStore.startListening(userId: userId)
                didShowShareSheetIntroForCurrentUser = didShowShareSheetIntro(for: userId)
                selectedTab = 0
            } else {
                clipsStore.stopListening()
                categoriesStore.stopListening()
                didShowShareSheetIntroForCurrentUser = false
            }
        }
        .onChange(of: clipsStore.clips.count) { oldCount, newCount in
            guard auth.userId != nil else { return }
            guard !didRequestReviewAfterThreeClips else { return }
            guard oldCount < 3, newCount >= 3 else { return }
            requestReview()
            didRequestReviewAfterThreeClips = true
        }
        .onAppear {
            if let uid = auth.userId {
                didShowShareSheetIntroForCurrentUser = didShowShareSheetIntro(for: uid)
            }
        }
        .onChange(of: categoryCacheInputs) { _, _ in updateCachedCombinedCategories() }
        .onAppear { updateCachedCombinedCategories() }
    }

    private func didShowShareSheetIntro(for userId: String) -> Bool {
        UserDefaults.standard.bool(forKey: "didShowShareSheetIntro_\(userId)")
    }

    private func setDidShowShareSheetIntro(_ value: Bool, for userId: String?) {
        guard let userId else { return }
        UserDefaults.standard.set(value, forKey: "didShowShareSheetIntro_\(userId)")
    }

    private func updateCategory(clipId: String, category: String) async {
        guard let uid = auth.userId else {
            auth.showError("Please sign in.")
            return
        }
        do {
            try await clipsStore.updateCategory(userId: uid, clipId: clipId, category: category)
        } catch {
            auth.showError("Couldn't update category. Please try again.")
        }
    }

    private func updateNotes(clipId: String, notes: String) async {
        guard let uid = auth.userId else {
            auth.showError("Please sign in.")
            return
        }
        do {
            try await clipsStore.updateNotes(userId: uid, clipId: clipId, notes: notes)
        } catch {
            auth.showError("Couldn't save notes. Please try again.")
        }
    }

    private var authView: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Spacer(minLength: 0)
                        authHeader
                        authInputs
                        authActions
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height * 0.75)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    private var authHeader: some View {
        VStack(spacing: 10) {
            if let icon = Self.cachedAppIconUIImage {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 86, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(accentColor.opacity(0.7), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
            }

            Text("ScrollMine")
                .font(.largeTitle).bold()
                .foregroundColor(primaryText)

            Text(isLoginMode ? "Log in to your account" : "Create your account")
                .foregroundColor(primaryText.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }

    private var authInputs: some View {
        let placeholderColor = primaryText.opacity(ThemeColors.placeholderOpacity(from: themeBackground))
        return VStack(spacing: 14) {
            TextField("", text: $auth.email, prompt: Text("Email").foregroundColor(placeholderColor))
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .padding()
                .background(primaryText.opacity(ThemeColors.inputFillOpacity(from: themeBackground)))
                .foregroundColor(primaryText)
                .cornerRadius(12)

            SecureField("", text: $auth.password, prompt: Text("Password").foregroundColor(placeholderColor))
                .padding()
                .background(primaryText.opacity(ThemeColors.inputFillOpacity(from: themeBackground)))
                .foregroundColor(primaryText)
                .cornerRadius(12)
        }
        .frame(maxWidth: authFormMaxWidth)
    }

    private var authActions: some View {
        VStack(spacing: 14) {
            if let error = auth.authError {
                Text(error).foregroundColor(.red).font(.callout)
            }
            if let info = auth.authInfo {
                Text(info).foregroundColor(primaryText.opacity(0.7)).font(.callout)
            }

            Button {
                Task { isLoginMode ? await auth.signIn() : await auth.signUp() }
            } label: {
                Text(isLoginMode ? "Log In" : "Create Account")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accentColor)
                    .foregroundColor(.white) // Keep white for contrast on accent
                    .cornerRadius(12)
            }

            Button {
                isLoginMode.toggle()
            } label: {
                Text(isLoginMode
                     ? "Need an account? Create one"
                     : "Already have an account? Log in")
                    .foregroundColor(accentColor)
                    .font(.callout)
            }

            if isLoginMode {
                Button {
                    Task { await auth.sendPasswordReset() }
                } label: {
                    Text("Forgot password?")
                        .foregroundColor(primaryText.opacity(0.7))
                        .font(.callout)
                }
                .padding(.top, 2)

                authProviderButtons
            }
        }
        .frame(maxWidth: authFormMaxWidth)
    }

    private var authProviderButtons: some View {
        VStack(spacing: 10) {
            SignInWithAppleButton(.signIn) { request in
                let nonce = auth.randomNonceString()
                appleNonce = nonce
                request.requestedScopes = [.email]
                request.nonce = auth.sha256(nonce)
            } onCompletion: { result in
                switch result {
                case .success(let authResult):
                    guard
                        let credential = authResult.credential as? ASAuthorizationAppleIDCredential,
                        let tokenData = credential.identityToken,
                        let token = String(data: tokenData, encoding: .utf8),
                        let nonce = appleNonce
                    else {
                        auth.showError("Apple sign-in failed.")
                        return
                    }
                    Task { await auth.signInWithApple(idToken: token, nonce: nonce, fullName: credential.fullName) }
                case .failure:
                    auth.showError("Apple sign-in failed.")
                }
            }
            .signInWithAppleButtonStyle(themeBackground == "white" ? .black : .white)
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                guard let vc = Self.topViewControllerForPresenting() else {
                    auth.showError("Could not present sign-in.")
                    return
                }
                Task { await auth.signInWithGoogle(presenting: vc) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Sign in with Google")
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(primaryText.opacity(0.08))
                .foregroundColor(primaryText)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(.top, 6)
    }

    private static func topViewControllerForPresenting() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }


    private func tabItem(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .semibold))
    }

    private func updateCachedCombinedCategories() {
        cachedCombinedCategories = categoriesStore.customCategories + categoriesStore.activeDefaultCategories
    }

    fileprivate static let lightHapticGenerator = UIImpactFeedbackGenerator(style: .light)
    fileprivate static let linkHapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    private func lightHaptic() {
        Self.lightHapticGenerator.prepare()
        Self.lightHapticGenerator.impactOccurred()
    }
}

private func contentViewLightHaptic() {
    ContentView.lightHapticGenerator.prepare()
    ContentView.lightHapticGenerator.impactOccurred()
}

private func contentViewLinkHaptic() {
    ContentView.linkHapticGenerator.prepare()
    ContentView.linkHapticGenerator.impactOccurred()
}

private struct VerifyEmailView: View {
    @ObservedObject var auth: AuthViewModel
    @AppStorage(ThemeColors.backgroundKey) private var themeBackground = ThemeColors.defaultBackground
    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
    @State private var resendCooldownRemaining: Int = 0

    private var primaryText: Color { ThemeColors.primaryText(from: themeBackground) }
    private var backgroundColor: Color { ThemeColors.background(from: themeBackground) }
    private var accentColor: Color { ThemeColors.color(from: themeAccent) }

    private var userEmail: String {
        auth.user?.email ?? "your email"
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Text("Verify your email")
                        .font(.title2).bold()
                        .foregroundColor(primaryText)

                    (Text("We sent a verification link to ")
                        + Text(userEmail).fontWeight(.semibold)
                        + Text(". Tap the button in that email to continue."))
                        .font(.callout)
                        .foregroundColor(primaryText.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    Text("If you don't see it, check your spam or junk folder.")
                        .font(.subheadline)
                        .foregroundColor(primaryText.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    if resendCooldownRemaining > 0 {
                        Text("Resend available in \(resendCooldownRemaining)s")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(primaryText.opacity(0.6))
                    } else {
                        Button {
                            resendCooldownRemaining = 60
                            Task { await auth.resendVerificationEmail() }
                        } label: {
                            Text("Resend verification email")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(primaryText)
                                .background(primaryText.opacity(0.12))
                                .cornerRadius(12)
                        }
                    }

                    Button {
                        Task { await auth.refreshUser() }
                    } label: {
                        Text("I've verified")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(themeBackground == "white" ? .black : .white)
                            .background(themeBackground == "white" ? Color.white : accentColor)
                            .cornerRadius(12)
                    }

                    Button {
                        auth.signOut()
                    } label: {
                        Text("Sign out")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(primaryText.opacity(0.7))
                    }
                    .padding(.top, 4)

                    if let error = auth.authError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    } else if let info = auth.authInfo {
                        Text(info)
                            .foregroundColor(primaryText.opacity(0.7))
                            .font(.footnote)
                    }
                }
                .padding(24)
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                if resendCooldownRemaining > 0 {
                    resendCooldownRemaining -= 1
                }
            }
        }
    }
}


private struct TabBarHapticsObserver: UIViewControllerRepresentable {
    let onUserSelect: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onUserSelect: onUserSelect)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let tabBarController = uiViewController.tabBarController else { return }
        if context.coordinator.tabBarController !== tabBarController {
            context.coordinator.attach(to: tabBarController)
        }
    }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        private let onUserSelect: (Int) -> Void
        private(set) weak var tabBarController: UITabBarController?

        init(onUserSelect: @escaping (Int) -> Void) {
            self.onUserSelect = onUserSelect
        }

        func attach(to tabBarController: UITabBarController) {
            self.tabBarController = tabBarController
            tabBarController.delegate = self
        }

        func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
            true
        }

        func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            onUserSelect(tabBarController.selectedIndex)
        }
    }
}

private struct ClipDetailModal: View {
    let clip: Clip
    let clipNumber: Int?
    let categories: [String]
    let onSelectCategory: (String) -> Void
    let onDismiss: () -> Void
    let onSaveNotes: (String) -> Void
    let onDelete: () -> Void
    @State private var isNotesExpanded = false
    @State private var isTranscriptExpanded = true
    @State private var showNotesSheet = false
    @State private var showShareSheet = false
    @State private var showDeleteConfirm = false
    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
    @AppStorage(ThemeColors.backgroundKey) private var themeBackground = ThemeColors.defaultBackground
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "M/d/yy"
        return df
    }()

    @Environment(\.openURL) private var openURL
    private var accentColor: Color { ThemeColors.color(from: themeAccent) }
    private var primaryText: Color { ThemeColors.primaryText(from: themeBackground) }
    private var backgroundColor: Color { ThemeColors.background(from: themeBackground) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
                HStack {
                    categoryCapsule
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(primaryText.opacity(ThemeColors.inputFillOpacity(from: themeBackground)))
                            .cornerRadius(12)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(clipNumberText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(primaryText.opacity(0.6))
                        .underline(true, color: primaryText.opacity(0.6))

                    if let url = URL(string: clip.url) {
                        Button {
                            contentViewLinkHaptic()
                            openURL(url)
                        } label: {
                            Image(systemName: "link")
                                .font(.system(size: 13.65, weight: .medium))
                                .foregroundColor(accentColor)
                        }
                        .buttonStyle(.plain)
                        .onAppear { ContentView.linkHapticGenerator.prepare() }
                    } else {
                        Image(systemName: "link")
                            .font(.system(size: 13.65, weight: .medium))
                            .foregroundColor(accentColor.opacity(0.35))
                    }

                    Text(clip.platform)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(primaryText.opacity(0.7))
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Personal notes (above transcript)
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                contentViewLightHaptic()
                                withAnimation(.easeInOut(duration: 0.2)) { isNotesExpanded.toggle() }
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.pencil")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(accentColor)
                                    Text("Personal notes")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(primaryText)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(primaryText.opacity(0.7))
                                        .rotationEffect(.degrees(isNotesExpanded ? 90 : 0))
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if isNotesExpanded {
                                if let notes = clip.personalNotes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.system(size: 15, weight: .regular))
                                        .lineSpacing(3)
                                        .foregroundColor(primaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Button {
                                        showNotesSheet = true
                                    } label: {
                                        Text("Edit notes")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(accentColor)
                                    }
                                    .padding(.top, 4)
                                } else {
                                    Button {
                                        showNotesSheet = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 14))
                                            Text("Add notes")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundColor(accentColor)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }

                        // Collapsible transcript
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                contentViewLightHaptic()
                                withAnimation(.easeInOut(duration: 0.2)) { isTranscriptExpanded.toggle() }
                            } label: {
                                HStack {
                                    Image(systemName: "person.wave.2")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(accentColor)
                                    Text("Transcript")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(primaryText)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(primaryText.opacity(0.7))
                                        .rotationEffect(.degrees(isTranscriptExpanded ? 90 : 0))
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if isTranscriptExpanded {
                                Text(capitalizeFirstLetter(clip.transcript))
                                    .font(.system(size: 16, weight: .light))
                                    .lineSpacing(3)
                                    .foregroundColor(primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.top, 10)
                .sheet(isPresented: $showNotesSheet) {
                    ClipNotesSheet(
                        title: "Clip \(clipNumber ?? 0)",
                        initialNotes: clip.personalNotes ?? "",
                        onSave: { notes in
                            onSaveNotes(notes)
                            showNotesSheet = false
                        },
                        onCancel: { showNotesSheet = false }
                    )
                }

                Spacer(minLength: 10)

                HStack {
                    Menu {
                        if let url = URL(string: clip.url) {
                            Button {
                                contentViewLightHaptic()
                                showShareSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Text("Share Clip Link")
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                        }
                        Button(role: .destructive) {
                            contentViewLightHaptic()
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete Clip")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(accentColor)
                            .padding(7)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(dateFormatter.string(from: clip.createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(primaryText.opacity(0.6))
                }
            }
            .padding(16)
            .sheet(isPresented: $showShareSheet) {
                if let url = URL(string: clip.url) {
                    ModalShareSheetView(activityItems: [url])
                }
            }
            .alert("Delete Clip?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { onDelete() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this clip?")
            }
            .background(backgroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(accentColor.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 8)
            .frame(maxWidth: 324)
            .frame(maxHeight: 481)
            .padding(.horizontal, 24)
            .onTapGesture {}
    }

    private var categoryCapsule: some View {
        Menu {
            ForEach(categories, id: \.self) { category in
                Button(category) { onSelectCategory(category) }
            }
        } label: {
            Text(clip.category.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(accentColor.opacity(ThemeColors.accentTintOpacity(from: themeBackground)))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(accentColor.opacity(themeBackground == "white" ? 0.5 : 0.35), lineWidth: ThemeColors.capsuleAndCardBorderWidth)
                )
                .fixedSize(horizontal: true, vertical: false)
                .animation(.spring(response: 0.32, dampingFraction: 0.88), value: clip.category)
        }
    }

    private var clipNumberText: String {
        if let number = clipNumber {
            return "Clip \(number):"
        }
        return "Clip"
    }

    private func capitalizeFirstLetter(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }

}

private struct ModalShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
