//
//  ContentView.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/23/26.
//
import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var auth = AuthViewModel()
    @StateObject private var clipsStore = ClipsStore()
    @StateObject private var vm: MineViewModel

    @State private var selectedClip: Clip?
    @State private var isLoginMode = false
    @State private var selectedTab = 1

    init() {
        let auth = AuthViewModel()
        let store = ClipsStore()
        _auth = StateObject(wrappedValue: auth)
        _clipsStore = StateObject(wrappedValue: store)
        _vm = StateObject(wrappedValue: MineViewModel(auth: auth, clipsStore: store))
    }

    var body: some View {
        Group {
            if auth.user != nil {
                TabView(selection: $selectedTab) {
                    DashboardView(clips: clipsStore.clips, selectedClip: $selectedClip)
                        .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                        .tag(0)

                    MineView(vm: vm, clipsStore: clipsStore, selectedClip: $selectedClip)
                        .tabItem { Label("Mine", systemImage: "bolt.fill") }
                        .tag(1)

                    SettingsView {
                        auth.signOut()
                    }
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(2)
                }
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
            } else {
                clipsStore.stopListening()
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
}
