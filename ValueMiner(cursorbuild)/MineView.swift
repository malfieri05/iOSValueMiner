//
//  MineView.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/24/26.
//

import SwiftUI
import Combine

struct MineView: View {
    @ObservedObject var vm: MineViewModel
    @ObservedObject var clipsStore: ClipsStore
    @Binding var selectedClip: Clip?

    var body: some View {
        VStack(spacing: 16) {
            TextField("Paste a video URL", text: $vm.urlText)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)

            Button {
                Task { await vm.mine() }
            } label: {
                HStack {
                    if vm.isLoading { ProgressView().tint(.white) }
                    Text(vm.isLoading ? "Mining..." : "Mine").bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.pink.opacity(vm.isLoading ? 0.6 : 1))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(vm.isLoading)

            if let error = vm.errorMessage {
                Text(error).foregroundColor(.red).font(.callout)
            } else if let info = vm.infoMessage {
                Text(info).foregroundColor(.orange).font(.callout)
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(clipsStore.clips.enumerated()), id: \.element.id) { index, clip in
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
