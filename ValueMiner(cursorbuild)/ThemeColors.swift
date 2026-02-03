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
    static let defaultAccent = ThemeAccent.purple.rawValue

    static let options: [(id: ThemeAccent, name: String, color: Color)] = [
        (.purple, "Purple", Color(red: 164/255, green: 93/255, blue: 233/255)),
        (.blue, "Blue", Color(red: 92/255, green: 161/255, blue: 255/255)),
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
            return UIColor(red: 92/255, green: 161/255, blue: 255/255, alpha: 1)
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
