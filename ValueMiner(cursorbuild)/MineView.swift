//
//  MineView.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/24/26.

import SwiftUI
import Combine
import UIKit

struct MineView: View {
    @ObservedObject var vm: MineViewModel
    @ObservedObject var clipsStore: ClipsStore
    @ObservedObject var categoriesStore: CategoriesStore
    @Binding var selectedClip: Clip?
    @Binding var selectedClipNumber: Int?
    let onSelectCategory: (Clip, String) -> Void

    var body: some View {
        ZStack {
            Color(red: 16/255, green: 18/255, blue: 32/255).ignoresSafeArea()
            VStack(spacing: 16) {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(clipsStore.clips.enumerated()), id: \.element.id) { index, clip in
                            let clipNumber = clipsStore.clips.count - index
                            ClipCard(
                                clipNumber: clipNumber,
                                clip: clip,
                                categories: categoriesStore.customCategories + categoriesStore.defaultCategories,
                                onSelectCategory: { category in onSelectCategory(clip, category) },
                                onExpand: {
                                    selectedClip = clip
                                    selectedClipNumber = clipNumber
                                },
                                onDelete: {
                                    guard let userId = vm.auth.userId else { return }
                                    Task {
                                        do {
                                            try await clipsStore.deleteClip(userId: userId, clipId: clip.id)
                                        } catch {
                                            print("Delete clip error:", error)
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 16)
                }
                .refreshable {
                    // Trigger refresh by re-listening to clips
                    if let userId = vm.auth.userId {
                        clipsStore.startListening(userId: userId)
                        categoriesStore.startListening(userId: userId)
                    }
                }
            }
        }
    }
}
