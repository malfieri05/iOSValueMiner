//
//  ShareSheetOnboardingView.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 2/1/26.
//

import SwiftUI
import UIKit

struct ShareSheetOnboardingView: View {
    let onDismiss: () -> Void
    let allowsEarlyDismiss: Bool

    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
    @State private var currentPage = 0

    private var accent: Color { ThemeColors.color(from: themeAccent) }

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
                    Text(allowsEarlyDismiss ? "Close" : "Got it")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(buttonBackground)
                        .cornerRadius(12)
                }
                .padding(.top, 4)
                .disabled(!allowsEarlyDismiss && currentPage != 3)
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

    private var buttonBackground: Color {
        if allowsEarlyDismiss { return accent }
        return currentPage == 3 ? accent : Color.white.opacity(0.15)
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

private struct ShareSheetSlide: View {
    let title: String
    let symbol: String

    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
    private var accent: Color { ThemeColors.color(from: themeAccent) }

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

    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
    private var accent: Color { ThemeColors.color(from: themeAccent) }

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
