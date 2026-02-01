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

@main
struct ValueMiner_cursorguild_App: App {
    init() {
        FirebaseApp.configure()
        try? Auth.auth().useUserAccessGroup("L6HK4D37VH.group.org.valueminer.shared")
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
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
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
