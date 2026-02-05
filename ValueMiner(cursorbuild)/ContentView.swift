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

struct ContentView: View {
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
    @AppStorage("didShowShareSheetIntro") private var didShowShareSheetIntro = false
    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent

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

    var body: some View {
        Group {
            if auth.user != nil {
                if !didShowShareSheetIntro {
                    ShareSheetOnboardingView(onDismiss: {
                        didShowShareSheetIntro = true
                    }, allowsEarlyDismiss: false)
                } else if auth.requiresEmailVerification {
                    VerifyEmailView(auth: auth)
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
                                Task { try? await clipsStore.updateCategory(userId: auth.userId ?? "", clipId: clip.id, category: category) }
                            }
                        )
                        .tabItem { tabItem(systemImage: "bolt.fill") }
                        .tag(0)

                        SettingsView(
                            onSignOut: {
                                auth.signOut()
                            },
                            subscriptionManager: subscriptionManager
                        )
                        .tabItem { tabItem(systemImage: "scroll.fill") }
                        .tag(1)
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
                        Group {
                            if let clip = selectedClip {
                                ClipDetailModal(
                                    clip: clip,
                                    clipNumber: selectedClipNumber,
                                    categories: categoriesStore.customCategories + categoriesStore.defaultCategories,
                                    onSelectCategory: { category in
                                        Task { try? await clipsStore.updateCategory(userId: auth.userId ?? "", clipId: clip.id, category: category) }
                                    },
                                    onDismiss: {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                            selectedClip = nil
                                            selectedClipNumber = nil
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
                selectedTab = 0
            } else {
                clipsStore.stopListening()
                categoriesStore.stopListening()
            }
        }
    }

    private var authView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 0)
                    authHeader
                    authInputs
                    authActions
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: UIScreen.main.bounds.height * 0.75)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var authHeader: some View {
        VStack(spacing: 10) {
            if let icon = appIconUIImage {
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
                .foregroundColor(.white)

            Text(isLoginMode ? "Log in to your account" : "Create your account")
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }

    private var authInputs: some View {
        VStack(spacing: 14) {
            TextField("Email", text: $auth.email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .padding()
                .background(Color.white.opacity(0.08))
                .foregroundColor(.white)
                .cornerRadius(12)

            SecureField("Password", text: $auth.password)
                .padding()
                .background(Color.white.opacity(0.08))
                .foregroundColor(.white)
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
                Text(info).foregroundColor(.white.opacity(0.7)).font(.callout)
            }

            Button {
                Task { isLoginMode ? await auth.signIn() : await auth.signUp() }
            } label: {
                Text(isLoginMode ? "Log In" : "Create Account")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accentColor)
                    .foregroundColor(.white)
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
                        .foregroundColor(.white.opacity(0.7))
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
            .signInWithAppleButtonStyle(.white)
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.top, 6)
    }

    private var appIconUIImage: UIImage? {
        if let name = primaryAppIconName(), let img = UIImage(named: name) {
            return img
        }
        // Some builds may expose the icon under this name; safe fallback.
        return UIImage(named: "AppIcon")
    }

    private func primaryAppIconName() -> String? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String],
            let name = files.last
        else { return nil }
        return name
    }

    private func tabItem(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .semibold))
    }

    private func lightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
}

private struct VerifyEmailView: View {
    @ObservedObject var auth: AuthViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Verify your email")
                    .font(.title2).bold()
                    .foregroundColor(.white)

                Text("We sent a verification link to your email. Please verify to continue.")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                Button {
                    Task { await auth.resendVerificationEmail() }
                } label: {
                    Text("Resend verification email")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.white)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(12)
                }

                Button {
                    Task { await auth.refreshUser() }
                } label: {
                    Text("I've verified")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.black)
                        .background(Color.white)
                        .cornerRadius(12)
                }

                Button {
                    auth.signOut()
                } label: {
                    Text("Sign out")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 4)

                if let error = auth.authError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                } else if let info = auth.authInfo {
                    Text(info)
                        .foregroundColor(.white.opacity(0.7))
                        .font(.footnote)
                }
            }
            .padding(24)
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
    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "M/d/yy"
        return df
    }()

    private var accentColor: Color { ThemeColors.color(from: themeAccent) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

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
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(clipNumberText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .underline(true, color: .white.opacity(0.6))

                    if let url = URL(string: clip.url) {
                        Link(destination: url) {
                            Image(systemName: "link")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(accentColor)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        })
                    } else {
                        Image(systemName: "link")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(accentColor.opacity(0.35))
                    }

                    Text(clip.platform)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }

                ScrollView {
                    Text(capitalizeFirstLetter(clip.transcript))
                        .font(.system(size: 16, weight: .light))
                        .lineSpacing(3)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 10)

                Spacer(minLength: 10)

                HStack {
                    Spacer()
                    Text(dateFormatter.string(from: clip.createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(16)
            // Midpoint between old navy (16/18/32) and black
            .background(Color(red: 8/255, green: 9/255, blue: 16/255))
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
                .background(accentColor.opacity(0.2))
                .cornerRadius(14)
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

