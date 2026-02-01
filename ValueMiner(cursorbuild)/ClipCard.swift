//
//  ClipCard.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/25/26.
//
import SwiftUI
import UIKit

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
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                // Category capsule
                Menu {
                    ForEach(categories, id: \.self) { category in
                        Button(category) { onSelectCategory(category) }
                    }
                } label: {
                    Text(clip.category.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 164/255, green: 93/255, blue: 233/255))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 164/255, green: 93/255, blue: 233/255).opacity(0.2))
                        .cornerRadius(14)
                        .frame(minWidth: capsuleMinWidth(), alignment: .leading)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: false)
                        .transaction { $0.animation = nil }
                }

                Spacer()

                Menu {
                    if let _ = wrapperShareURL() {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showShareSheet = true
                        } label: {
                            Text("Share Clip Link")
                        }
                    } else {
                        Text("Share Clip Link")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("Delete Clip")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                })
            }

            // Row with Clip #, Link, and platform on same line
            HStack(alignment: .firstTextBaseline) {
                Text("Clip \(clipNumber)")
                    .font(.system(size: 12, weight: .medium))

                if let url = URL(string: clip.url) {
                    Link("Link", destination: url)
                        .font(.system(size: 12, weight: .medium))
                        .underline(true, color: .white.opacity(0.6))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("Link")
                        .font(.system(size: 12, weight: .medium))
                        .underline(true, color: .white.opacity(0.6))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Text(clip.platform)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
            }

            // Transcript preview
            Text(capitalizeFirstLetter(clip.transcript))
                .font(.system(size: 14, weight: .regular))
                .lineLimit(3)
                .foregroundColor(.white)

            // Date at bottom right
            HStack {
                Spacer()
                Text(clipDateFormatter.string(from: clip.createdAt))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .foregroundColor(.white)
        .padding(14)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 164/255, green: 93/255, blue: 233/255).opacity(0.9), lineWidth: 1.2)
        )
        .cornerRadius(16)
        .contentShape(Rectangle())
        .onTapGesture {
            onExpand()
        }
        .alert("Delete Clip?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this clip?")
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = wrapperShareURL() {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private func capsuleMinWidth() -> CGFloat {
        let font = UIFont.systemFont(ofSize: 12, weight: .bold)
        let maxTextWidth = categories
            .map { ($0.uppercased() as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        let horizontalPadding: CGFloat = 24 // matches .padding(.horizontal, 12)
        return maxTextWidth + horizontalPadding
    }

    private func capitalizeFirstLetter(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }

    private func wrapperShareURL() -> URL? {
        let encoded = clip.url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        guard let encoded else { return nil }
        return URL(string: "https://valueminer.org/s?u=\(encoded)&src=app")
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
