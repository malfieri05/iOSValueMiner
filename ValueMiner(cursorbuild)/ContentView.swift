//
//  ContentView.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/23/26.
//

import SwiftUI
import Combine
import UIKit

struct ContentView: View {
    @StateObject private var auth = AuthViewModel()
    @StateObject private var clipsStore = ClipsStore()
    @StateObject private var categoriesStore = CategoriesStore()
    @StateObject private var vm: MineViewModel

    @State private var selectedClip: Clip?
    @State private var selectedClipNumber: Int?
    @State private var isLoginMode = false
    @State private var selectedTab = 0
    @AppStorage("didShowShareSheetIntro") private var didShowShareSheetIntro = false

    init() {
        let auth = AuthViewModel()
        let store = ClipsStore()
        let categories = CategoriesStore()
        _auth = StateObject(wrappedValue: auth)
        _clipsStore = StateObject(wrappedValue: store)
        _categoriesStore = StateObject(wrappedValue: categories)
        _vm = StateObject(wrappedValue: MineViewModel(auth: auth, clipsStore: store))
    }
    
    private let authFormMaxWidth: CGFloat = 360

    var body: some View {
        Group {
            if auth.user != nil {
                if !didShowShareSheetIntro {
                    ShareSheetOnboardingView {
                        didShowShareSheetIntro = true
                    }
                } else {
                    TabView(selection: $selectedTab) {
                        DashboardView(
                            clips: clipsStore.clips,
                            clipsStore: clipsStore,
                            vm: vm,
                            selectedClip: $selectedClip,
                            selectedClipNumber: $selectedClipNumber,
                            categoriesStore: categoriesStore,
                            userId: auth.userId,
                            onSelectCategory: { clip, category in
                                Task { try? await clipsStore.updateCategory(userId: auth.userId ?? "", clipId: clip.id, category: category) }
                            }
                        )
                        .tabItem { tabItem(systemImage: "bolt.fill") }
                        .tag(0)

                        SettingsView {
                            auth.signOut()
                        }
                        .tabItem { tabItem(systemImage: "scroll.fill") }
                        .tag(1)
                    }
                    .background(
                        TabBarHapticsObserver {
                            lightHaptic()
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

            // Center the INPUTS on screen (simple + reliable),
            // then place header above and actions below.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                authInputs
                Spacer(minLength: 0)
            }
            .padding()
            .overlay(alignment: .center) {
                authHeader
                    .offset(y: -160)
            }
            .overlay(alignment: .center) {
                authActions
                    .offset(y: 120)
            }
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
                            .stroke(Color(red: 164/255, green: 93/255, blue: 233/255).opacity(0.7), lineWidth: 1)
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

            Button {
                Task { isLoginMode ? await auth.signIn() : await auth.signUp() }
            } label: {
                Text(isLoginMode ? "Log In" : "Create Account")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 164/255, green: 93/255, blue: 233/255))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }

            Button {
                isLoginMode.toggle()
            } label: {
                Text(isLoginMode
                     ? "Need an account? Create one"
                     : "Already have an account? Log in")
                    .foregroundColor(Color(red: 164/255, green: 93/255, blue: 233/255))
                    .font(.callout)
            }
        }
        .frame(maxWidth: authFormMaxWidth)
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

private struct ShareSheetOnboardingView: View {
    let onDismiss: () -> Void

    private let accent = Color(red: 164/255, green: 93/255, blue: 233/255)
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 18) {
                if let icon = appIconImage() {
                    Image(uiImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 82, height: 82)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(accent.opacity(0.7), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 6)
                        .padding(.bottom, 6)
                }

                Text("Save clips without leaving your scroll!")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Add 'ScrollMine' to your Share Sheet ONCE, then save clips in ONE TAP.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                TabView(selection: $currentPage) {
                    ShareSheetSlide(
                        title: "1) Tap SHARE on any video",
                        symbol: "square.and.arrow.up"
                    )
                    .tag(0)

                    ShareSheetSlide(
                        title: "2) Swipe to the end of the app row -> tap MORE",
                        symbol: "ellipsis.circle"
                    )
                    .tag(1)

                    ShareSheetSlide(
                        title: "3) Tap EDIT (top-right)",
                        symbol: "pencil.circle"
                    )
                    .tag(2)

                    ShareSheetSlide(
                        title: "4) Tap '+' to add ScrollMine to Favorites, then drag ☰ to put reorder priority",
                        symbol: "line.3.horizontal.decrease.circle"
                    )
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 240)

                ShareSheetPageDots(total: 4, currentIndex: currentPage)

                Button(action: onDismiss) {
                    Text("Got it")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(currentPage == 3 ? accent : Color.white.opacity(0.15))
                        .cornerRadius(12)
                }
                .padding(.top, 4)
                .disabled(currentPage != 3)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(accent.opacity(0.6), lineWidth: 1.4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            )
        }
    }

    private func appIconImage() -> UIImage? {
        if
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String],
            let name = files.last,
            let img = UIImage(named: name)
        {
            return img
        }
        return UIImage(named: "AppIcon")
    }
}

private struct ShareStepRow: View {
    let number: String
    let icon: String?
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(text)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

private struct ShareSheetSlide: View {
    let title: String
    let symbol: String

    private let accent = Color(red: 164/255, green: 93/255, blue: 233/255)

    var body: some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Image(systemName: symbol)
                .font(.system(size: 60, weight: .semibold))
                .foregroundColor(accent)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ShareSheetPageDots: View {
    let total: Int
    let currentIndex: Int

    private let accent = Color(red: 164/255, green: 93/255, blue: 233/255)

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? accent : Color.white.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.top, 2)
    }
}

private struct TabBarHapticsObserver: UIViewControllerRepresentable {
    let onUserSelect: () -> Void

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
        private let onUserSelect: () -> Void
        private(set) weak var tabBarController: UITabBarController?

        init(onUserSelect: @escaping () -> Void) {
            self.onUserSelect = onUserSelect
        }

        func attach(to tabBarController: UITabBarController) {
            self.tabBarController = tabBarController
            tabBarController.delegate = self
        }

        func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
            onUserSelect()
            return true
        }
    }
}

private struct ClipDetailModal: View {
    let clip: Clip
    let clipNumber: Int?
    let categories: [String]
    let onSelectCategory: (String) -> Void
    let onDismiss: () -> Void
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "M/d/yy"
        return df
    }()

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
                            .foregroundColor(Color(red: 164/255, green: 93/255, blue: 233/255))
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
                                .foregroundColor(Color(red: 164/255, green: 93/255, blue: 233/255))
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        })
                    } else {
                        Image(systemName: "link")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 164/255, green: 93/255, blue: 233/255).opacity(0.35))
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
                    .stroke(Color(red: 164/255, green: 93/255, blue: 233/255).opacity(0.6), lineWidth: 1)
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
                .foregroundColor(Color(red: 164/255, green: 93/255, blue: 233/255))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(red: 164/255, green: 93/255, blue: 233/255).opacity(0.2))
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

