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

@main
struct ValueMiner_cursorguild_App: App {
    init() {
        FirebaseApp.configure()
        try? Auth.auth().useUserAccessGroup("L6HK4D37VH.com.valueminer.shared")
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
}
