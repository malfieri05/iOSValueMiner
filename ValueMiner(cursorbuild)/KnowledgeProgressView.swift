//
//  KnowledgeProgressView.swift
//  ValueMiner(cursorbuild)
//

import SwiftUI
import UIKit
import LinkPresentation

struct KnowledgeProgressView: View {
    @ObservedObject var clipsStore: ClipsStore
    @ObservedObject var categoriesStore: CategoriesStore
    let userId: String?

    @State private var selectedCategory: String = "All"
    @State private var showLearnMore = false
    @State private var milestoneToShow: MilestoneAlert?
    @State private var previousWordCounts: [String: Int] = [:]
    @State private var animateProgress = false
    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
    @AppStorage(ThemeColors.backgroundKey) private var themeBackground = ThemeColors.defaultBackground

    private var accentColor: Color { ThemeColors.color(from: themeAccent) }
    private var primaryText: Color { ThemeColors.primaryText(from: themeBackground) }
    private var backgroundColor: Color { ThemeColors.background(from: themeBackground) }

    private var categories: [String] {
        let custom = categoriesStore.customCategories
        let defaults = categoriesStore.activeDefaultCategories.filter { $0 != "All" && $0 != "Other" }
        return ["All"] + custom + defaults + ["Other"]
    }

    /// Categories shown in the Library tab picker (excludes "Other"; milestones still fire for "All").
    private var pickerCategories: [String] {
        categories.filter { $0 != "Other" }
    }

    /// Categories that have clips, sorted by clip count descending (most clips/books on top).
    private var displayOrderedCategories: [String] {
        categories
            .filter { $0 != "All" && $0 != "Other" && clipsStore.clipCount(for: $0) > 0 }
            .sorted { clipsStore.clipCount(for: $0) > clipsStore.clipCount(for: $1) }
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    mainProgressCard
                    categoryBreakdownSection
                    learnMoreButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            loadPreviousWordCounts()
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateProgress = true
            }
        }
        .onChange(of: clipsStore.clips) { _, _ in
            checkForMilestones()
            cacheWordCounts()
            savePreviousWordCounts()
        }
        .sheet(isPresented: $showLearnMore) {
            BookEquivalentExplainerView()
        }
        .alert(item: $milestoneToShow) { milestone in
            Alert(
                title: Text(milestone.title),
                message: Text(milestone.message),
                dismissButton: .default(Text("Keep Mining!"))
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(accentColor)
                Text("Knowledge Library")
                    .font(.title2.bold())
                    .foregroundColor(primaryText)
                Spacer()

                Button {
                    lightHaptic()
                    showLearnMore = true
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(accentColor)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text("Track your learning progress across topics")
                    .font(.subheadline)
                    .foregroundColor(primaryText.opacity(0.6))
                Spacer()
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Main Progress Card

    private var mainProgressCard: some View {
        VStack(spacing: 20) {
            ZStack(alignment: .center) {
                HStack {
                    Spacer(minLength: 0)
                    categoryPicker
                        .frame(width: 200)
                    Spacer(minLength: 0)
                }
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        lightHaptic()
                        shareProgressCard()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(accentColor)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                }
            }
            .frame(height: 44)

            let books = clipsStore.completedBooks(for: selectedCategory)
            let progress = clipsStore.progressToNextBook(for: selectedCategory)
            let words = clipsStore.wordCount(for: selectedCategory)
            let clips = clipsStore.clipCount(for: selectedCategory)

            circularProgressRing(books: books, progress: progress)

            statsRow(words: words, clips: clips, books: books)

            progressBarSection(progress: progress, words: words)
        }
        .padding(20)
        .background(ThemeColors.glassCardBackground(from: themeBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accentColor.opacity(themeBackground == "white" ? 0.6 : 0.3), lineWidth: ThemeColors.feedCardAndProfileBoxBorderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .cardDepthShadow(themeBackground: themeBackground)
    }

    private func shareProgressCard() {
        let books = clipsStore.completedBooks(for: selectedCategory)
        let progress = clipsStore.progressToNextBook(for: selectedCategory)
        let words = clipsStore.wordCount(for: selectedCategory)
        let clips = clipsStore.clipCount(for: selectedCategory)
        let shareCard = KnowledgeProgressShareCardView(
            category: selectedCategory,
            books: books,
            progress: progress,
            words: words,
            clips: clips,
            themeAccent: themeAccent,
            themeBackground: themeBackground
        )
        .frame(width: 340)
        let renderer = ImageRenderer(content: shareCard)
        renderer.scale = 2
        guard let image = renderer.uiImage,
              let shareImage = Self.imageForSharing(image),
              let top = Self.topViewController() else { return }
        let activityItems: [Any]
        if let appStoreURL = Config.appStoreURL {
            let linkItem = KnowledgeProgressShareItemSource(
                appStoreURL: appStoreURL,
                previewImage: shareImage,
                category: selectedCategory
            )
            activityItems = [shareImage, linkItem]
        } else {
            assertionFailure("APP_STORE_URL missing in Secrets.plist; sharing image without store link.")
            activityItems = [shareImage]
        }

        let activity = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        if let pop = activity.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        top.present(activity, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { ($0 as? UIWindowScene)?.activationState == .foregroundActive }) as? UIWindowScene,
              let window = scene.windows.first(where: \.isKeyWindow),
              var vc = window.rootViewController else { return nil }
        while let presented = vc.presentedViewController { vc = presented }
        return vc
    }

    /// Resize and compress for fast share handoff (e.g. Messages); keeps quality good for the card.
    private static func imageForSharing(_ image: UIImage) -> UIImage? {
        let maxSide: CGFloat = 680
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(maxSide / size.width, maxSide / size.height, 1)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized
    }

    private var categoryPicker: some View {
        Menu {
            ForEach(pickerCategories, id: \.self) { category in
                Button {
                    selectedCategory = category
                } label: {
                    Label(category, systemImage: category == selectedCategory ? "checkmark.circle.fill" : "circle")
                }
            }
        } label: {
            categoryPickerLabel
        }
        .animation(.easeInOut(duration: 0.22), value: selectedCategory)
    }

    /// Stable-size label so the button never resizes or clips when the selected category changes.
    private var categoryPickerLabel: some View {
        HStack(spacing: 8) {
            Text(selectedCategory)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .center)

            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(accentColor)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(primaryText.opacity(ThemeColors.inputFillOpacity(from: themeBackground)))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func circularProgressRing(books: Int, progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(primaryText.opacity(0.1), lineWidth: 16)
                .frame(width: 160, height: 160)

            Circle()
                .trim(from: 0, to: animateProgress ? progress : 0)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [accentColor.opacity(0.6), accentColor]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0), value: animateProgress)
                .animation(.easeOut(duration: 0.5), value: progress)

            VStack(spacing: 2) {
                Text("\(books)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(primaryText)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: books)

                Text(books == 1 ? "Book" : "Books")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(primaryText.opacity(0.6))
            }
        }
        .padding(.vertical, 8)
    }

    private func statsRow(words: Int, clips: Int, books: Int) -> some View {
        HStack(spacing: 0) {
            statItem(value: formatNumber(words), label: "Words", icon: "text.alignleft")
            Divider()
                .frame(height: 40)
                .background(primaryText.opacity(0.2))
            statItem(value: "\(clips)", label: "Clips", icon: "doc.text")
            Divider()
                .frame(height: 40)
                .background(primaryText.opacity(0.2))
            statItem(value: "\(books)", label: "Books", icon: "book.closed")
        }
        .padding(.vertical, 8)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(accentColor)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(primaryText)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(primaryText.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func progressBarSection(progress: Double, words: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress to next book")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(primaryText.opacity(0.7))
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(primaryText.opacity(0.1))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.8), accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * (animateProgress ? progress : 0), height: 12)
                        .animation(.easeOut(duration: 1.0), value: animateProgress)
                        .animation(.easeOut(duration: 0.5), value: progress)

                    milestoneMarkers(width: geo.size.width, progress: progress)
                }
            }
            .frame(height: 12)

            let wordsRemaining = ClipsStore.wordsPerBookEquivalent - (words % ClipsStore.wordsPerBookEquivalent)
            let actualRemaining = wordsRemaining == ClipsStore.wordsPerBookEquivalent && progress == 0 ? ClipsStore.wordsPerBookEquivalent : wordsRemaining

            Text("\(formatNumber(actualRemaining)) words to next book")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(primaryText.opacity(0.5))
        }
    }

    private func milestoneMarkers(width: CGFloat, progress: Double) -> some View {
        ZStack {
            ForEach([0.25, 0.5, 0.75], id: \.self) { milestone in
                Circle()
                    .fill(progress >= milestone ? accentColor : primaryText.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .offset(x: width * milestone - 4)
            }
        }
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Category")
                .font(.headline)
                .foregroundColor(primaryText)

            if displayOrderedCategories.isEmpty {
                Text("Start saving clips to see your progress by category!")
                    .font(.subheadline)
                    .foregroundColor(primaryText.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(displayOrderedCategories, id: \.self) { category in
                        categoryProgressRow(category: category)
                    }
                }
            }
        }
    }

    private func categoryProgressRow(category: String) -> some View {
        let books = clipsStore.completedBooks(for: category)
        let progress = clipsStore.progressToNextBook(for: category)
        let clips = clipsStore.clipCount(for: category)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(primaryText)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 11))
                            .foregroundColor(accentColor)
                        Text("\(books)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(accentColor)
                    }
                }

                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(primaryText.opacity(0.1))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(accentColor.opacity(0.8))
                                .frame(width: geo.size.width * progress, height: 6)
                        }
                    }
                    .frame(height: 6)

                    Text("\(clips) clips")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(primaryText.opacity(0.5))
                        .fixedSize()
                }
            }
        }
        .padding(14)
        .background(primaryText.opacity(ThemeColors.inputFillOpacity(from: themeBackground)))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Learn More

    private var learnMoreButton: some View {
        Button {
            lightHaptic()
            showLearnMore = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .medium))
                Text("How is this calculated?")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(accentColor)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(accentColor.opacity(ThemeColors.accentTintOpacity(from: themeBackground)))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Helpers

    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            let thousands = Double(number) / 1000.0
            return String(format: "%.1fK", thousands)
        }
        return "\(number)"
    }

    private var previousWordCountsKey: String {
        "libraryPreviousWordCounts_\(userId ?? "anon")"
    }

    private func loadPreviousWordCounts() {
        guard let raw = UserDefaults.standard.dictionary(forKey: previousWordCountsKey) as? [String: Int] else { return }
        previousWordCounts = raw
    }

    private func savePreviousWordCounts() {
        UserDefaults.standard.set(previousWordCounts, forKey: previousWordCountsKey)
    }

    private func cacheWordCounts() {
        for category in categories {
            previousWordCounts[category] = clipsStore.wordCount(for: category)
        }
    }

    private func checkForMilestones() {
        for category in pickerCategories {
            guard let previousCount = previousWordCounts[category] else { continue }
            if let milestone = clipsStore.checkMilestone(for: category, previousWordCount: previousCount) {
                let books = clipsStore.completedBooks(for: category)
                milestoneToShow = MilestoneAlert(
                    category: category,
                    milestone: milestone,
                    booksCompleted: books
                )
                break
            }
        }
    }

    private static let lightHapticGenerator = UIImpactFeedbackGenerator(style: .light)
    private func lightHaptic() {
        Self.lightHapticGenerator.prepare()
        Self.lightHapticGenerator.impactOccurred()
    }
}

private final class KnowledgeProgressShareItemSource: NSObject, UIActivityItemSource {
    private let appStoreURL: URL
    private let previewImage: UIImage
    private let category: String

    init(appStoreURL: URL, previewImage: UIImage, category: String) {
        self.appStoreURL = appStoreURL
        self.previewImage = previewImage
        self.category = category
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        appStoreURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        appStoreURL
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = appStoreURL
        metadata.url = appStoreURL
        metadata.title = "ScrollMine: \(category) progress report"
        metadata.imageProvider = NSItemProvider(object: previewImage)
        if let icon = Self.appIconImage() {
            metadata.iconProvider = NSItemProvider(object: icon)
        }
        return metadata
    }

    private static func appIconImage() -> UIImage? {
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

// MARK: - Shareable progress card (rendered as image for sharing)

private struct KnowledgeProgressShareCardView: View {
    let category: String
    let books: Int
    let progress: Double
    let words: Int
    let clips: Int
    let themeAccent: String
    let themeBackground: String

    private var accentColor: Color { ThemeColors.color(from: themeAccent) }
    private var primaryText: Color { ThemeColors.primaryText(from: themeBackground) }
    private var shareWordsRemaining: Int {
        let wr = ClipsStore.wordsPerBookEquivalent - (words % ClipsStore.wordsPerBookEquivalent)
        return (wr == ClipsStore.wordsPerBookEquivalent && progress == 0) ? ClipsStore.wordsPerBookEquivalent : wr
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(category)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(primaryText)
                .frame(maxWidth: .infinity)

            ZStack {
                Circle()
                    .stroke(primaryText.opacity(0.1), lineWidth: 16)
                    .frame(width: 160, height: 160)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [accentColor.opacity(0.6), accentColor]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(books)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                    Text(books == 1 ? "Book" : "Books")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(primaryText.opacity(0.6))
                }
            }
            .padding(.vertical, 8)

            HStack(spacing: 0) {
                shareStatItem(value: formatShareNumber(words), label: "Words", icon: "text.alignleft")
                Divider()
                    .frame(height: 40)
                    .background(primaryText.opacity(0.2))
                shareStatItem(value: "\(clips)", label: "Clips", icon: "doc.text")
                Divider()
                    .frame(height: 40)
                    .background(primaryText.opacity(0.2))
                shareStatItem(value: "\(books)", label: "Books", icon: "book.closed")
            }
            .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress to next book")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(primaryText.opacity(0.7))
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(primaryText.opacity(0.1))
                            .frame(height: 12)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.8), accentColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress, height: 12)
                    }
                }
                .frame(height: 12)
                Text("\(formatShareNumber(shareWordsRemaining)) words to next book")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(primaryText.opacity(0.5))
            }
        }
        .padding(20)
        .background(ThemeColors.glassCardBackground(from: themeBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accentColor.opacity(themeBackground == "white" ? 0.6 : 0.3), lineWidth: ThemeColors.feedCardAndProfileBoxBorderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func shareStatItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(accentColor)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(primaryText)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(primaryText.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func formatShareNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000.0)
        }
        return "\(number)"
    }
}

// MARK: - Milestone Alert Model

struct MilestoneAlert: Identifiable {
    let id = UUID()
    let category: String
    let milestone: Double
    let booksCompleted: Int

    var title: String {
        switch milestone {
        case 1.0:
            return "Book Completed!"
        case 0.75:
            return "75% There!"
        case 0.5:
            return "Halfway!"
        case 0.25:
            return "Great Start!"
        default:
            return "Milestone!"
        }
    }

    var message: String {
        switch milestone {
        case 1.0:
            return "You've gathered a book's worth of knowledge in \(category)! That's \(booksCompleted) book\(booksCompleted == 1 ? "" : "s") total."
        case 0.75:
            return "You're 75% of the way to another book equivalent in \(category). Keep going!"
        case 0.5:
            return "You're halfway to completing another book's worth of knowledge in \(category)!"
        case 0.25:
            return "You're 25% of the way to a book equivalent in \(category). Great progress!"
        default:
            return "You've made progress in \(category)!"
        }
    }
}
