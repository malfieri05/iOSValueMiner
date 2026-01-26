//
//  SettingsView.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/24/26.
//

import SwiftUI

struct SettingsView: View {
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Settings")
                .font(.title2).bold()

            Button("Sign Out") {
                onSignOut()
            }
            .foregroundColor(.red)
        }
        .padding()
    }
}
