//
//  MineView.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/24/26.
//
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
                VStack(spacing: 16) {
                    TextField("Paste a video URL", text: $vm.urlText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(12)

                    Button {
                        lightHaptic()
                        Task { await vm.mine() }
                    } label: {
                        HStack {
                            if vm.isLoading { ProgressView().tint(.white) }
                            Text(vm.isLoading ? "Mining..." : "Mine").bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 164/255, green: 93/255, blue: 233/255).opacity(vm.isLoading ? 0.6 : 1))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(vm.isLoading)

                    if let error = vm.errorMessage {
                        Text(error).foregroundColor(.red).font(.callout)
                    } else if let info = vm.infoMessage {
                        Text(info).foregroundColor(.orange).font(.callout)
                    }
                }
                .padding(.horizontal, 16)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(clipsStore.clips.enumerated()), id: \.element.id) { index, clip in
                            let clipNumber = clipsStore.clips.count - index
                            ClipCard(
                                clipNumber: clipNumber,
                                clip: clip,
                                categories: categoriesStore.defaultCategories.dropFirst() + categoriesStore.customCategories,
                                onSelectCategory: { category in onSelectCategory(clip, category) },
                                onExpand: {
                                    selectedClip = clip
                                    selectedClipNumber = clipNumber
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

    private func lightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
}
