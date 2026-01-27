//
//  ClipCard.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/25/26.
//

import SwiftUI

private let clipDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateFormat = "M/d/yy"
    return df
}()

struct ClipCard: View {
    let clipNumber: Int
    let clip: Clip
    let categories: [String]
    let onSelectCategory: (String) -> Void
    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            VStack(alignment: .leading, spacing: 10) {
                // Top row with Clip #, date, and platform on same line
                HStack(alignment: .firstTextBaseline) {
                    Text("Clip \(clipNumber)")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(clipDateFormatter.string(from: clip.createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Text(clip.platform)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }

                // Category menu label under Clip #
                Menu {
                    ForEach(categories, id: \.self) { category in
                        Button(category) { onSelectCategory(category) }
                    }
                } label: {
                    Text(clip.category.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 164/255, green: 93/255, blue: 233/255))
                        .padding(.vertical, 2)
                }

                // Transcript preview
                Text(clip.transcript)
                    .font(.system(size: 14, weight: .regular))
                    .lineLimit(3)
                    .foregroundColor(.white)
            }
            .foregroundColor(.white)
            .padding(14)
            .background(Color.white.opacity(0.08))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}
