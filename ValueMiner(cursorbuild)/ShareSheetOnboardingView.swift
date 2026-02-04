//
//  ShareSheetOnboardingView.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 2/1/26.
//

import SwiftUI
import UIKit
import AVFoundation
import AVKit

struct ShareSheetOnboardingView: View {
    let onDismiss: () -> Void
    let allowsEarlyDismiss: Bool

    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
    @State private var currentPage = 0
    @State private var showVideoFullscreen = false

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
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)

                LoopingVideoView(
                    resourceName: "Onboarding Instructions",
                    fileExtension: "mov"
                )
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(accent.opacity(0.25), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    Button(action: { showVideoFullscreen = true }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(8)
                }

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
        .fullScreenCover(isPresented: $showVideoFullscreen) {
            FullscreenPlayerView(
                resourceName: "Onboarding Instructions",
                fileExtension: "mov"
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

private struct LoopingVideoView: View {
    let resourceName: String
    let fileExtension: String

    var body: some View {
        if let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) {
            LoopingPlayerRepresentable(url: url)
        } else {
            ZStack {
                Color.white.opacity(0.04)
                Text("Video not found")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

private struct FullscreenPlayerView: View {
    let resourceName: String
    let fileExtension: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) {
                PlayerViewControllerRepresentable(url: url)
                    .ignoresSafeArea()
            } else {
                Text("Video not found")
                    .foregroundColor(.white.opacity(0.7))
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(16)
                Spacer()
            }
        }
    }
}

private struct LoopingPlayerRepresentable: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(items: [item])
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        let controller = AVPlayerViewController()
        controller.player = queuePlayer
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        context.coordinator.queuePlayer = queuePlayer
        context.coordinator.looper = looper
        queuePlayer.play()
        queuePlayer.isMuted = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var queuePlayer: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }
}

private struct PlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        player.play()
        player.isMuted = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
