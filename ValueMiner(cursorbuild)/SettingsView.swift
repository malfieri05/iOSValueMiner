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
        ZStack {
            Color(red: 16/255, green: 18/255, blue: 32/255).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Settings")
                    .font(.title2).bold()
                    .foregroundColor(.white)

                Button("Sign Out") {
                    onSignOut()
                }
                .foregroundColor(.red)
            }
            .padding()
        }
    }
}
