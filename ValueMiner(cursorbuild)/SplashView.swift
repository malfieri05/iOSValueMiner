//
//  SplashView.swift
//  ValueMiner(cursorbuild)
//
//  Blank white screen with app icon only (no border). Shown briefly on launch.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        Color.white
            .ignoresSafeArea()
            .overlay {
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
            }
    }
}

#Preview {
    SplashView()
}
