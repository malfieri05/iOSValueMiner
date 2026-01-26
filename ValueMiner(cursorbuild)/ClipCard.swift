//
//  ClipCard.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/25/26.
//

import SwiftUI

struct ClipCard: View {
    let clipNumber: Int
    let clip: Clip
    let onSelectCategory: (String) -> Void
    let onExpand: () -> Void

    private let categories = [
        "Business", "Health", "Mindset", "Politics", "Productivity", "Religion", "Other"
    ]

    var body: some View {
        Button(action: onExpand) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Clip \(clipNumber)")
                        .font(.headline)
                    Spacer()
                    Text(clip.platform)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Menu {
                    ForEach(categories, id: \.self) { category in
                        Button(category) { onSelectCategory(category) }
                    }
                } label: {
                    Text(clip.category)
                        .font(.subheadline)
                        .foregroundColor(.pink)
                }

                Text(clip.transcript)
                    .font(.callout)
                    .lineLimit(2)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}
