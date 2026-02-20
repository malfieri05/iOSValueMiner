//
//  ThemeColors.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 2/2/26.
//

import SwiftUI
import UIKit

enum ThemeAccent: String, CaseIterable {
    case purple
    case blue
    case green
    case red
    case orange
    case pink
    case teal
    case white
}

struct ThemeColors {
    static let defaultAccent = ThemeAccent.blue.rawValue
    static let backgroundKey = "themeBackground"
    static let defaultBackground = "black"

    static func background(from raw: String) -> Color {
        raw == "white" ? .white : .black
    }

    static func primaryText(from raw: String) -> Color {
        raw == "white" ? .black : .white
    }

    static func primaryTextUI(from raw: String) -> UIColor {
        raw == "white" ? .black : .white
    }

    /// Opacity for input/button fills. Higher on white theme for visibility.
    static func inputFillOpacity(from raw: String) -> Double {
        raw == "white" ? 0.13 : 0.08
    }

    /// Placeholder text opacity in inputs. Higher on white theme so placeholders read on light gray fill.
    static func placeholderOpacity(from raw: String) -> Double {
        raw == "white" ? 0.65 : 0.5
    }

    /// Opacity for accent-tinted backgrounds (pills, tags). Higher on white theme.
    static func accentTintOpacity(from raw: String) -> Double {
        raw == "white" ? 0.32 : 0.2
    }

    /// Opacity for subtle borders on inputs/buttons. Defines edges on white theme.
    static func inputStrokeOpacity(from raw: String) -> Double {
        raw == "white" ? 0.2 : 0.12
    }

    /// Opacity for pill/cell fills (UIKit). Higher on white theme.
    static func pillFillOpacity(from raw: String) -> CGFloat {
        raw == "white" ? 0.13 : 0.08
    }

    /// Opacity for selected pill accent tint. Higher on white theme for visibility.
    static func pillAccentTintOpacity(from raw: String) -> CGFloat {
        raw == "white" ? 0.38 : 0.25
    }

    /// Opacity for secondary buttons (e.g. Done, Cancel). Higher on white theme.
    static func secondaryButtonFillOpacity(from raw: String) -> Double {
        raw == "white" ? 0.25 : 0.2
    }

    /// Border width for category capsules (thin).
    static let capsuleAndCardBorderWidth: CGFloat = 1.2

    /// Border width for clip cards in feed and profile tab boxes (2× capsule).
    static let feedCardAndProfileBoxBorderWidth: CGFloat = 2.4

    /// Corner radius for inputs and buttons (URL bar, Save, Add Category, search, etc.) to match clip cards.
    static let inputAndButtonCornerRadius: CGFloat = 16

    // MARK: - Liquid glass / raised depth (clip cards, etc.)

    /// Translucent fill for glass-style cards. Background shows through.
    static func glassCardBackground(from raw: String) -> Color {
        raw == "white" ? Color.white.opacity(0.82) : Color.white.opacity(0.06)
    }

    /// Opacity for top-left highlight gradient on glass cards (glossy edge).
    static let glassHighlightOpacity: Double = 0.28

    /// Opacity for subtle inner-shadow gradient on glass cards (top-left recess).
    static let glassInnerShadowOpacity: Double = 0.045

    /// Slightly lighter highlight for inputs/bars (smaller surface).
    static let glassInputHighlightOpacity: Double = 0.22

    /// Stronger highlight for accent buttons (Save, Add Clip, FAB).
    static let glassButtonHighlightOpacity: Double = 0.38

    // MARK: - Shadow (barely noticeable on black background)

    static func shadowOpacityCardPrimary(from raw: String) -> Double {
        raw == "white" ? 0.12 : 0.012
    }
    static func shadowOpacityCardSecondary(from raw: String) -> Double {
        raw == "white" ? 0.06 : 0.006
    }
    static func shadowOpacityBar(from raw: String) -> Double {
        raw == "white" ? 0.05 : 0
    }
    static func shadowOpacityButton(from raw: String) -> Double {
        raw == "white" ? 0.07 : 0
    }
    static func shadowOpacityFABPrimary(from raw: String) -> Double {
        raw == "white" ? 0.2 : 0.02
    }
    static func shadowOpacityFABSecondary(from raw: String) -> Double {
        raw == "white" ? 0.12 : 0.01
    }

    /// Rich, saturated accent colors (blue unchanged as reference).
    static let options: [(id: ThemeAccent, name: String, color: Color)] = [
        (.purple, "Purple", Color(red: 147/255.0, green: 51/255.0, blue: 234/255.0)),
        (.blue, "Blue", Color(red: 0/255.0, green: 122/255.0, blue: 255/255.0)),
        (.green, "Green", Color(red: 34/255.0, green: 197/255.0, blue: 94/255.0)),
        (.red, "Red", Color(red: 239/255.0, green: 68/255.0, blue: 68/255.0)),
        (.orange, "Orange", Color(red: 249/255.0, green: 115/255.0, blue: 22/255.0)),
        (.pink, "Pink", Color(red: 236/255.0, green: 72/255.0, blue: 153/255.0)),
        (.teal, "Teal", Color(red: 20/255.0, green: 184/255.0, blue: 166/255.0)),
        (.white, "White", Color.white),
    ]

    static func color(from raw: String) -> Color {
        let accent = ThemeAccent(rawValue: raw) ?? .purple
        return options.first { $0.id == accent }?.color ?? options[0].color
    }

    static func uiColor(from raw: String) -> UIColor {
        switch ThemeAccent(rawValue: raw) ?? .purple {
        case .purple:
            return UIColor(red: 147/255.0, green: 51/255.0, blue: 234/255.0, alpha: 1)
        case .blue:
            return UIColor(red: 0/255.0, green: 122/255.0, blue: 255/255.0, alpha: 1)
        case .green:
            return UIColor(red: 34/255.0, green: 197/255.0, blue: 94/255.0, alpha: 1)
        case .red:
            return UIColor(red: 239/255.0, green: 68/255.0, blue: 68/255.0, alpha: 1)
        case .orange:
            return UIColor(red: 249/255.0, green: 115/255.0, blue: 22/255.0, alpha: 1)
        case .pink:
            return UIColor(red: 236/255.0, green: 72/255.0, blue: 153/255.0, alpha: 1)
        case .teal:
            return UIColor(red: 20/255.0, green: 184/255.0, blue: 166/255.0, alpha: 1)
        case .white:
            return UIColor.white
        }
    }
}

extension View {
    /// Raised / liquid glass depth: soft drop shadow; subtler on black background.
    func cardDepthShadow(themeBackground: String = "white") -> some View {
        Group {
            if themeBackground == "white" {
                self
                    .shadow(color: Color.black.opacity(ThemeColors.shadowOpacityCardPrimary(from: themeBackground)), radius: 8, x: 2, y: 4)
                    .shadow(color: Color.black.opacity(ThemeColors.shadowOpacityCardSecondary(from: themeBackground)), radius: 14, x: 0, y: 6)
            } else {
                self
            }
        }
    }

    /// Liquid glass style for input bars (URL field, search bar). No inner shadow/highlight/stroke/shadow in dark mode.
    func glassBarStyle(themeBackground: String, strokeColor: Color, cornerRadius: CGFloat = ThemeColors.inputAndButtonCornerRadius) -> some View {
        Group {
            if themeBackground == "white" {
                self
                    .background(ThemeColors.glassCardBackground(from: themeBackground))
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(ThemeColors.glassInnerShadowOpacity), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .allowsHitTesting(false)
                    )
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(ThemeColors.glassInputHighlightOpacity), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .allowsHitTesting(false)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(strokeColor.opacity(0.25), lineWidth: 1)
                            .allowsHitTesting(false)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .shadow(color: Color.black.opacity(ThemeColors.shadowOpacityBar(from: themeBackground)), radius: 6, x: 1, y: 3)
            } else {
                self
                    .background(ThemeColors.glassCardBackground(from: themeBackground))
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
    }

    /// Glossy top-left highlight for accent buttons. No highlight in dark mode.
    func glassButtonHighlight(themeBackground: String) -> some View {
        Group {
            if themeBackground == "white" {
                self.overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(ThemeColors.glassButtonHighlightOpacity), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: ThemeColors.inputAndButtonCornerRadius, style: .continuous))
                    .allowsHitTesting(false)
                )
            } else {
                self
            }
        }
    }
}
