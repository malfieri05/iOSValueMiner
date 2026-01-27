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
    @State private var isLoginMode = false
    @State private var selectedTab = 1

    init() {
        let auth = AuthViewModel()
        let store = ClipsStore()
        let categories = CategoriesStore()
        _auth = StateObject(wrappedValue: auth)
        _clipsStore = StateObject(wrappedValue: store)
        _categoriesStore = StateObject(wrappedValue: categories)
        _vm = StateObject(wrappedValue: MineViewModel(auth: auth, clipsStore: store))
    }

    var body: some View {
        Group {
            if auth.user != nil {
                TabView(selection: $selectedTab) {
                    DashboardView(
                        clips: clipsStore.clips,
                        clipsStore: clipsStore,
                        selectedClip: $selectedClip,
                        categoriesStore: categoriesStore,
                        userId: auth.userId,
                        onSelectCategory: { clip, category in
                            Task { try? await clipsStore.updateCategory(userId: auth.userId ?? "", clipId: clip.id, category: category) }
                        }
                    )
                    .tabItem { tabItem("Dashboard", systemImage: "square.grid.2x2") }
                    .tag(0)

                    MineView(
                        vm: vm,
                        clipsStore: clipsStore,
                        categoriesStore: categoriesStore,
                        selectedClip: $selectedClip,
                        onSelectCategory: { clip, category in
                            Task { try? await clipsStore.updateCategory(userId: auth.userId ?? "", clipId: clip.id, category: category) }
                        }
                    )
                    .tabItem { tabItem("Mine", systemImage: "bolt.fill") }
                    .tag(1)

                    SettingsView {
                        auth.signOut()
                    }
                    .tabItem { tabItem("Profile", systemImage: "person.circle") }
                    .tag(2)
                }
                .background(
                    TabBarHapticsObserver {
                        lightHaptic()
                    }
                )
                .sheet(item: $selectedClip) { clip in
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Clip Transcript")
                            .font(.title2).bold()
                        Text("\(clip.platform) • \(clip.category)")
                            .foregroundColor(.secondary)
                        ScrollView {
                            Text(clip.transcript)
                                .font(.body)
                        }
                    }
                    .padding()
                }
            } else {
                authView
            }
        }
        .onChange(of: auth.userId) { _, newValue in
            if let userId = newValue {
                clipsStore.startListening(userId: userId)
                categoriesStore.startListening(userId: userId)
            } else {
                clipsStore.stopListening()
                categoriesStore.stopListening()
            }
        }
    }

    private var authView: some View {
        ZStack {
            Color(red: 16/255, green: 18/255, blue: 32/255).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("ValueMiner")
                    .font(.largeTitle).bold()
                    .foregroundColor(.white)

                Text(isLoginMode ? "Log in to your account" : "Create your account")
                    .foregroundColor(.white.opacity(0.8))

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
                .padding(.top, 4)
            }
            .padding()
        }
    }

    private func tabItem(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .regular))
            Text(title)
                .font(.system(size: 8, weight: .regular))
        }
    }

    private func lightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
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
