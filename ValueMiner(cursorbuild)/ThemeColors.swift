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
    static let defaultBackground = "white"

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

    static let options: [(id: ThemeAccent, name: String, color: Color)] = [
        (.purple, "Purple", Color(red: 164/255, green: 93/255, blue: 233/255)),
        (.blue, "Blue", Color(red: 0/255, green: 122/255, blue: 255/255)),
        (.green, "Green", Color(red: 80/255, green: 200/255, blue: 120/255)),
        (.red, "Red", Color(red: 244/255, green: 92/255, blue: 92/255)),
        (.orange, "Orange", Color(red: 255/255, green: 159/255, blue: 67/255)),
        (.pink, "Pink", Color(red: 255/255, green: 105/255, blue: 180/255)),
        (.teal, "Teal", Color(red: 64/255, green: 196/255, blue: 212/255)),
        (.white, "White", Color.white),
    ]

    static func color(from raw: String) -> Color {
        let accent = ThemeAccent(rawValue: raw) ?? .purple
        return options.first { $0.id == accent }?.color ?? options[0].color
    }

    static func uiColor(from raw: String) -> UIColor {
        switch ThemeAccent(rawValue: raw) ?? .purple {
        case .purple:
            return UIColor(red: 164/255, green: 93/255, blue: 233/255, alpha: 1)
        case .blue:
            return UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1)
        case .green:
            return UIColor(red: 80/255, green: 200/255, blue: 120/255, alpha: 1)
        case .red:
            return UIColor(red: 244/255, green: 92/255, blue: 92/255, alpha: 1)
        case .orange:
            return UIColor(red: 255/255, green: 159/255, blue: 67/255, alpha: 1)
        case .pink:
            return UIColor(red: 255/255, green: 105/255, blue: 180/255, alpha: 1)
        case .teal:
            return UIColor(red: 64/255, green: 196/255, blue: 212/255, alpha: 1)
        case .white:
            return UIColor.white
        }
    }
}

extension View {
    /// Slight floating / depth effect for clip cards and profile boxes.
    func cardDepthShadow() -> some View {
        self
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 6)
    }
}
