//
//  ValueMiner_cursorbuild_App.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/23/26.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAuth
import UserNotifications

private struct LaunchSplashWrapper: View {
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: showSplash)
        .task {
            try? await Task.sleep(for: .seconds(1.0))
            showSplash = false
        }
    }
}

@main
struct ValueMiner_cursorbuild_App: App {
    init() {
        FirebaseApp.configure()
        try? Auth.auth().useUserAccessGroup("9Q6S64UNWA.group.org.valueminer.shared")
        requestNotificationPermissionIfNeeded()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            assertionFailure("Could not create persistent ModelContainer: \(error)")
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallbackConfiguration])
        }
    }()

    var body: some Scene {
        WindowGroup {
            LaunchSplashWrapper()
        }
        .modelContainer(sharedModelContainer)
    }

    private func requestNotificationPermissionIfNeeded() {
        let defaultsKey = "didRequestNotificationPermission"
        let defaults = UserDefaults.standard

        guard !defaults.bool(forKey: defaultsKey) else { return }
        defaults.set(true, forKey: defaultsKey)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
}
