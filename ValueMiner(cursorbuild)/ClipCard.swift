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

private let clipCardCapsuleFont = UIFont.systemFont(ofSize: 12, weight: .bold)

private enum ClipViewPreference {
    static let key = "clipTranscriptPreference"
    static func get(clipId: String) -> Bool {
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Bool] ?? [:]
        return dict[clipId] ?? true
    }
    static func set(clipId: String, showTranscript: Bool) {
        var dict = (UserDefaults.standard.dictionary(forKey: key) as? [String: Bool]) ?? [:]
        dict[clipId] = showTranscript
        UserDefaults.standard.set(dict, forKey: key)
    }
}

struct ClipCard: View {
    let clipNumber: Int
    let clip: Clip
    let categories: [String]
    let onSelectCategory: (String) -> Void
    let onExpand: () -> Void
    let onDelete: () -> Void
    let onSaveNotes: (String) -> Void

    @State private var showShareSheet = false
    @State private var showNotesSheet = false
    @State private var showTranscriptOnCard: Bool
    @State private var cachedThumbnailURL: URL?
    @State private var cachedCapsuleMinWidth: CGFloat?
    @Environment(\.openURL) private var openURL
    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
    @AppStorage(ThemeColors.backgroundKey) private var themeBackground = ThemeColors.defaultBackground

    init(clipNumber: Int, clip: Clip, categories: [String], onSelectCategory: @escaping (String) -> Void, onExpand: @escaping () -> Void, onDelete: @escaping () -> Void, onSaveNotes: @escaping (String) -> Void) {
        self.clipNumber = clipNumber
        self.clip = clip
        self.categories = categories
        self.onSelectCategory = onSelectCategory
        self.onExpand = onExpand
        self.onDelete = onDelete
        self.onSaveNotes = onSaveNotes
        _showTranscriptOnCard = State(initialValue: ClipViewPreference.get(clipId: clip.id))
    }

    private var accentColor: Color { ThemeColors.color(from: themeAccent) }
    private var primaryText: Color { ThemeColors.primaryText(from: themeBackground) }

    private static let lightHapticGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let linkHapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    private func lightHaptic() {
        Self.lightHapticGenerator.prepare()
        Self.lightHapticGenerator.impactOccurred()
    }
    private func linkHaptic() {
        Self.linkHapticGenerator.prepare()
        Self.linkHapticGenerator.impactOccurred()
    }

    private var cardContent: some View {
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
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(accentColor.opacity(ThemeColors.accentTintOpacity(from: themeBackground)))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(accentColor.opacity(themeBackground == "white" ? 0.5 : 0.35), lineWidth: ThemeColors.capsuleAndCardBorderWidth)
                        )
                        .frame(minWidth: cachedCapsuleMinWidth ?? capsuleMinWidth(), alignment: .leading)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: clip.category)
                        .onAppear {
                            if cachedCapsuleMinWidth == nil {
                                cachedCapsuleMinWidth = capsuleMinWidth()
                            }
                        }
                        .onChange(of: categories) { _, _ in
                            cachedCapsuleMinWidth = capsuleMinWidth()
                        }
                        .onChange(of: clip.category) { _, _ in
                            cachedCapsuleMinWidth = capsuleMinWidth()
                        }
                }

                Spacer()

                Button {
                    lightHaptic()
                    showNotesSheet = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(accentColor)
                        .padding(7)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if URL(string: clip.url) != nil {
                    Button {
                        lightHaptic()
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(accentColor)
                            .padding(7)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Row with Clip #, Link, and platform on same line
            HStack(alignment: .firstTextBaseline) {
                Text("Clip \(clipNumber):")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(primaryText.opacity(0.6))
                    .underline(true, color: primaryText.opacity(0.6))

                if let url = URL(string: clip.url) {
                    Button {
                        linkHaptic()
                        openURL(url)
                    } label: {
                        Image(systemName: "link")
                            .font(.system(size: 13.65, weight: .medium))
                            .foregroundColor(accentColor)
                    }
                    .buttonStyle(.plain)
                    .onAppear { Self.linkHapticGenerator.prepare() }
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 13.65, weight: .medium))
                        .foregroundColor(accentColor.opacity(0.35))
                }

                Spacer()

                Text(clip.platform)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(primaryText.opacity(0.7))
            }

            // Transcript or notes preview — fixed height so card size never changes
            Group {
                if showTranscriptOnCard {
                    Text(capitalizeFirstLetter(clip.transcript))
                } else {
                    Text((clip.personalNotes?.isEmpty == false) ? clip.personalNotes! : "No notes yet. Tap the note icon to add some.")
                        .foregroundColor((clip.personalNotes?.isEmpty == false) ? primaryText : primaryText.opacity(0.5))
                }
            }
            .font(.system(size: 14, weight: .regular))
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 52)

            // Bottom row: icon-only toggle (bottom left) + date (bottom right)
            HStack {
                Button {
                    lightHaptic()
                    showTranscriptOnCard.toggle()
                    ClipViewPreference.set(clipId: clip.id, showTranscript: showTranscriptOnCard)
                } label: {
                    HStack(spacing: 0) {
                        Image(systemName: "person.wave.2")
                            .font(.system(size: 12, weight: showTranscriptOnCard ? .semibold : .regular))
                            .foregroundColor(showTranscriptOnCard ? primaryText : primaryText.opacity(0.5))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                Group {
                                    if showTranscriptOnCard {
                                        UnevenRoundedRectangle(
                                            topLeadingRadius: 10,
                                            bottomLeadingRadius: 10,
                                            bottomTrailingRadius: 0,
                                            topTrailingRadius: 0,
                                            style: .continuous
                                        )
                                        .fill(accentColor.opacity(ThemeColors.accentTintOpacity(from: themeBackground)))
                                    }
                                }
                            )
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 12, weight: showTranscriptOnCard ? .regular : .semibold))
                            .foregroundColor(showTranscriptOnCard ? primaryText.opacity(0.5) : primaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                Group {
                                    if !showTranscriptOnCard {
                                        UnevenRoundedRectangle(
                                            topLeadingRadius: 0,
                                            bottomLeadingRadius: 0,
                                            bottomTrailingRadius: 10,
                                            topTrailingRadius: 10,
                                            style: .continuous
                                        )
                                        .fill(accentColor.opacity(ThemeColors.accentTintOpacity(from: themeBackground)))
                                    }
                                }
                            )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(primaryText.opacity(0.08))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(clipDateFormatter.string(from: clip.createdAt))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(primaryText.opacity(0.6))
            }
        }
    }

    private var thumbnailURL: URL? {
        if let cached = cachedThumbnailURL {
            return cached
        }
        if let urlString = thumbnailURLFromVideoURL(clip.url), let url = URL(string: urlString) {
            cachedThumbnailURL = url
            return url
        }
        return nil
    }

    private func thumbnailURLFromVideoURL(_ urlString: String) -> String? {
        let s = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, let url = URL(string: s), let host = url.host()?.lowercased() else { return nil }
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var videoID: String?
        if host.contains("youtu.be") {
            videoID = pathComponents.first
        } else if host.contains("youtube.com") {
            videoID = components.queryItems?.first(where: { $0.name == "v" })?.value
            if videoID == nil, pathComponents.count >= 2 {
                let pathFirst = pathComponents[0].lowercased()
                if pathFirst == "embed" || pathFirst == "v" { videoID = pathComponents[1] }
            }
        }
        guard let id = videoID, !id.isEmpty else { return nil }
        return "https://img.youtube.com/vi/\(id)/mqdefault.jpg"
    }

    @ViewBuilder
    private func thumbnailView(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                primaryText.opacity(0.15)
            case .empty:
                primaryText.opacity(0.15)
            @unknown default:
                primaryText.opacity(0.15)
            }
        }
        .frame(width: 88, height: 66)
        .fixedSize(horizontal: true, vertical: true)
        .background(accentColor.opacity(ThemeColors.accentTintOpacity(from: themeBackground)))
        .clipped()
        .cornerRadius(10)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            cardContent
                .frame(maxWidth: .infinity, alignment: .leading)
            if let thumbURL = thumbnailURL {
                thumbnailView(url: thumbURL)
            }
        }
        .onAppear {
            // Cache thumbnail URL on appear
            if cachedThumbnailURL == nil {
                if let urlString = thumbnailURLFromVideoURL(clip.url), let url = URL(string: urlString) {
                    cachedThumbnailURL = url
                }
            }
        }
        .onChange(of: clip.url) { _, _ in
            // Invalidate cache when clip URL changes
            cachedThumbnailURL = nil
            if let urlString = thumbnailURLFromVideoURL(clip.url), let url = URL(string: urlString) {
                cachedThumbnailURL = url
            }
        }
        .foregroundColor(primaryText)
        .padding(14)
        .background(ThemeColors.glassCardBackground(from: themeBackground))
        .overlay(
            Group {
                if themeBackground == "white" {
                    LinearGradient(
                        colors: [Color.black.opacity(ThemeColors.glassInnerShadowOpacity), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .allowsHitTesting(false)
        )
        .overlay(
            Group {
                if themeBackground == "white" {
                    LinearGradient(
                        colors: [Color.white.opacity(ThemeColors.glassHighlightOpacity), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accentColor.opacity(themeBackground == "white" ? 0.75 : 0.18), lineWidth: ThemeColors.feedCardAndProfileBoxBorderWidth)
                .allowsHitTesting(false)
        )
        .cornerRadius(16)
        .cardDepthShadow(themeBackground: themeBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            onExpand()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = URL(string: clip.url) {
                ShareSheet(activityItems: [ShareItemSource(url: url)])
            }
        }
        .sheet(isPresented: $showNotesSheet) {
            ClipNotesSheet(
                title: "Clip \(clipNumber)",
                initialNotes: clip.personalNotes ?? "",
                onSave: { notes in
                    onSaveNotes(notes)
                    showNotesSheet = false
                },
                onCancel: { showNotesSheet = false }
            )
        }
    }

    private func capsuleMinWidth() -> CGFloat {
        let maxTextWidth = categories
            .map { ($0.uppercased() as NSString).size(withAttributes: [.font: clipCardCapsuleFont]).width }
            .max() ?? 0
        let horizontalPadding: CGFloat = 24 // matches .padding(.horizontal, 12)
        return maxTextWidth + horizontalPadding
    }

    private func capitalizeFirstLetter(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }
}

struct ClipNotesSheet: View {
    let title: String
    let initialNotes: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var draftNotes: String = ""
    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
    @AppStorage(ThemeColors.backgroundKey) private var themeBackground = ThemeColors.defaultBackground

    private var accentColor: Color { ThemeColors.color(from: themeAccent) }
    private var primaryText: Color { ThemeColors.primaryText(from: themeBackground) }
    private var backgroundColor: Color { ThemeColors.background(from: themeBackground) }

    var body: some View {
        NavigationStack {
            TextEditor(text: $draftNotes)
                .scrollContentBackground(.hidden)
                .background(backgroundColor)
                .foregroundColor(primaryText)
                .font(.system(size: 16, weight: .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .onAppear { draftNotes = initialNotes }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text(title)
                                .font(.headline)
                                .foregroundColor(ThemeColors.primaryText(from: "black"))
                                .padding(.top, -4)
                            Text("Personal Notes")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(ThemeColors.primaryText(from: "black").opacity(0.85))
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { onCancel() }
                            .foregroundColor(accentColor)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(draftNotes)
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(accentColor)
                    }
                }
        }
        .presentationDetents([.medium])
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

// --- Added missing ClipDetailModal with updated category capsule as per instructions ---

private struct ClipDetailModal: View {
    let clip: Clip
    let categories: [String]
    let onSelectCategory: (String) -> Void

    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
    @AppStorage(ThemeColors.backgroundKey) private var themeBackground = ThemeColors.defaultBackground

    private var accentColor: Color { ThemeColors.color(from: themeAccent) }
    private var primaryText: Color { ThemeColors.primaryText(from: themeBackground) }

    var body: some View {
        VStack {
            categoryCapsule
            // Other UI here...
        }
    }

    private var categoryCapsule: some View {
        Menu {
            ForEach(categories, id: \.self) { category in
                Button(category) { onSelectCategory(category) }
            }
        } label: {
            Text(clip.category.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(accentColor.opacity(ThemeColors.accentTintOpacity(from: themeBackground)))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(accentColor.opacity(themeBackground == "white" ? 0.5 : 0.35), lineWidth: ThemeColors.capsuleAndCardBorderWidth)
                )
                .fixedSize(horizontal: true, vertical: false)
                .animation(.spring(response: 0.32, dampingFraction: 0.88), value: clip.category)
        }
    }
}
