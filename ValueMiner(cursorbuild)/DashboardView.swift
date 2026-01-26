//
//  DashboardView.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/24/26.
//

import SwiftUI

struct DashboardView: View {
    let clips: [Clip]
    @Binding var selectedClip: Clip?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your mined clips")
                .font(.title2).bold()

            Text("Newest clips appear first.")
                .foregroundColor(.secondary)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                        ClipCard(
                            clipNumber: index + 1,
                            clip: clip,
                            onSelectCategory: { _ in },
                            onExpand: { selectedClip = clip }
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
    }
}
