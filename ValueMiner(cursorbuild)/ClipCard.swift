//
//  ClipCard.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/25/26.
//
import SwiftUI
import UIKit
import LinkPresentation

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
                    if let url = URL(string: clip.url) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showShareSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Text("Share Clip Link")
                                Image(systemName: "square.and.arrow.up")
                            }
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
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(red: 164/255, green: 93/255, blue: 233/255))
                        .padding(7)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                })
            }

            // Row with Clip #, Link, and platform on same line
            HStack(alignment: .firstTextBaseline) {
                Text("Clip \(clipNumber):")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .underline(true, color: .white.opacity(0.6))

                if let url = URL(string: clip.url) {
                    Link(destination: url) {
                        Image(systemName: "link")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 164/255, green: 93/255, blue: 233/255))
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    })
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 164/255, green: 93/255, blue: 233/255).opacity(0.35))
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
            if let url = URL(string: clip.url) {
                ShareSheet(activityItems: [ShareItemSource(url: url)])
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
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private final class ShareItemSource: NSObject, UIActivityItemSource {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        url
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url
        metadata.title = "Saved with ScrollMine"

        if let icon = appIconImage() {
            metadata.iconProvider = NSItemProvider(object: icon)
        }

        return metadata
    }

    private func appIconImage() -> UIImage? {
        if
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String],
            let name = files.last,
            let img = UIImage(named: name)
        {
            return img
        }
        return UIImage(named: "AppIcon")
    }
}
