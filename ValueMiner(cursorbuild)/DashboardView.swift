//
//  DashboardView.swift
//  ValueMiner(cursorbuild)
//
//
//  DashboardView.swift
//  ValueMiner(cursorbuild)
//

import SwiftUI
import UIKit
import FirebaseFirestore

struct DashboardView: View {
    let clips: [Clip]
    @ObservedObject var clipsStore: ClipsStore
    @ObservedObject var vm: MineViewModel
    @Binding var selectedClip: Clip?
    @Binding var selectedClipNumber: Int?
    @Binding var mineTabResetCounter: Int
    @ObservedObject var categoriesStore: CategoriesStore
    let userId: String?
    let onSelectCategory: (Clip, String) -> Void

    @State private var categories: [Category] = []
    @State private var selectedCategoryId: UUID? = nil
    @State private var selectedCategoryIndex: Int = 0
    @State private var scrollProgress: CGFloat = 0
    @State private var showingAddCategory = false
    @State private var isAddCategoryExpanded = false
    @State private var newCategoryName: String = ""
    @State private var pendingDeleteCategory: Category?
    @State private var searchText = ""
    @State private var searchRowIndex = 0
    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent

    private var accentColor: Color { ThemeColors.color(from: themeAccent) }

    private var orderedCategoryTitles: [String] {
        let allCategory = categoriesStore.defaultCategories.first! // "All"
        let otherCategories = categoriesStore.defaultCategories.dropFirst().filter { $0 != "Other" }
        let otherCategory = "Other"
        // New custom categories appear in the first slot to the right of "All"
        return [allCategory] + categoriesStore.customCategories + otherCategories + [otherCategory]
    }

    private var totalCategoryCount: Int {
        orderedCategoryTitles.count
    }

    private var deletableTitles: Set<String> {
        Set(categoriesStore.customCategories)
    }


    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                headerView
                    .padding(.horizontal, 16)

                pagerView
            }
        }
        .onAppear {
            syncCategories(with: orderedCategoryTitles)
        }
        .onChange(of: orderedCategoryTitles) { _, newTitles in
            syncCategories(with: newTitles)
        }
        .onChange(of: categories) { _, newCategories in
            if let selectedId = selectedCategoryId,
               let idx = newCategories.firstIndex(where: { $0.id == selectedId }) {
                selectedCategoryIndex = idx
            } else {
                selectedCategoryIndex = 0
                selectedCategoryId = newCategories.first?.id
            }
        }
        .onChange(of: searchRowIndex) { _, newValue in
            if newValue == 1 {
                isAddCategoryExpanded = false
                selectAllCategory()
            } else {
                searchText = ""
            }
        }
        .onChange(of: mineTabResetCounter) { _, _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                searchRowIndex = 0
            }
            searchText = ""
            selectAllCategory()
        }
        .onChange(of: scrollProgress) { _, newProgress in
            let idx = Int(round(newProgress))
            if categories.indices.contains(idx) {
                selectedCategoryIndex = idx
                selectedCategoryId = categories[idx].id
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            VStack(spacing: 16) {
                Text("New category name")
                    .font(.headline)
                TextField("Category name", text: $newCategoryName)
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .onChange(of: newCategoryName) { _, newValue in
                        newCategoryName = clampCategoryName(newValue)
                    }
                HStack {
                    Button("Cancel") { showingAddCategory = false }
                    Spacer()
                    Button("Add") {
                        Task {
                            let name = clampCategoryName(newCategoryName).trimmingCharacters(in: .whitespacesAndNewlines)
                            if let uid = userId, !name.isEmpty {
                                try? await categoriesStore.addCategory(userId: uid, name: name)
                                newCategoryName = ""
                                showingAddCategory = false
                            }
                        }
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .presentationDetents([.height(220)])
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView(subscriptionManager: vm.subscriptionManager)
                .presentationDetents([.medium])
        }
        .alert(item: $pendingDeleteCategory) { category in
            Alert(
                title: Text("Remove \(category.title)?"),
                message: Text("Don't worry, the mined clips will remain in the 'All' tab if you proceed to delete '\(category.title)'."),
                primaryButton: .destructive(Text("Delete Category")) {
                    Task { await deleteCategory(named: category.title) }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func syncCategories(with titles: [String]) {
        guard !titles.isEmpty else {
            categories = []
            selectedCategoryId = nil
            selectedCategoryIndex = 0
            return
        }

        // Build the list in the exact order of titles, preserving UUIDs
        var newList: [Category] = []
        for title in titles {
            // Try to find existing category with same title to preserve its UUID
            if let existing = categories.first(where: { $0.title == title }) {
                newList.append(existing)
            } else {
                // New category - create with stable UUID
                newList.append(Category(id: idForTitle(title), title: title))
            }
        }

        categories = newList
        
        // Persist this order to UserDefaults so ReorderableCategoryBar respects it
        let persistenceKey = "category_bar_order_\(userId ?? "anon")"
        let ids = newList.map { $0.id.uuidString }
        UserDefaults.standard.set(ids, forKey: persistenceKey)

        if selectedCategoryId == nil || !categories.contains(where: { $0.id == selectedCategoryId }) {
            selectedCategoryId = categories.first?.id
            selectedCategoryIndex = 0
        }
    }

    private func idForTitle(_ title: String) -> UUID {
        let mapKey = "category_id_map_\(userId ?? "anon")"
        var map = UserDefaults.standard.dictionary(forKey: mapKey) as? [String: String] ?? [:]
        if let existing = map[title], let uuid = UUID(uuidString: existing) {
            return uuid
        }
        let newId = UUID()
        map[title] = newId.uuidString
        UserDefaults.standard.set(map, forKey: mapKey)
        return newId
    }

    private func lightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    private func clampCategoryName(_ value: String) -> String {
        let maxLength = 20
        if value.count <= maxLength { return value }
        return String(value.prefix(maxLength))
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("Your Mine.")
                    .font(.title2).bold()
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(searchRowIndex == 0 ? accentColor : Color.white.opacity(0.3))
                        .frame(width: 5, height: 5)
                    Circle()
                        .fill(searchRowIndex == 1 ? accentColor : Color.white.opacity(0.3))
                        .frame(width: 5, height: 5)
                }
            }

            TabView(selection: $searchRowIndex) {
                mineBarRow
                    .tag(0)
                searchBarRow
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 44)
            .background(Color.black)
            .animation(.easeInOut(duration: 0.25), value: isAddCategoryExpanded)

            if let info = vm.infoMessage {
                Text(info).foregroundColor(.orange).font(.callout)
            }

            if isAddCategoryExpanded {
            HStack(spacing: 8) {
                TextField(
                    "",
                    text: $newCategoryName,
                    prompt: Text("New category name")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                )
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 14))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .onChange(of: newCategoryName) { _, newValue in
                        newCategoryName = clampCategoryName(newValue)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                Button {
                    lightHaptic()
                    Task {
                        let name = clampCategoryName(newCategoryName).trimmingCharacters(in: .whitespacesAndNewlines)
                        if let uid = userId, !name.isEmpty {
                            try? await categoriesStore.addCategory(userId: uid, name: name)
                            newCategoryName = ""
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Category")
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                        Text("(\(totalCategoryCount))")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(accentColor.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                    }
                }
                .buttonStyle(ActionButtonStyle(accentColor: accentColor))
                .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || userId == nil)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            }

            ReorderableCategoryBar(
                categories: $categories,
                selectedCategoryId: $selectedCategoryId,
                persistenceKey: "category_bar_order_\(userId ?? "anon")",
                deletableTitles: deletableTitles,
                countProvider: { category in
                    if category.title == "All" { return clips.count }
                    return clips.filter { $0.category == category.title }.count
                }
            ) { category in
                selectedCategoryId = category.id
                if let idx = categories.firstIndex(where: { $0.id == category.id }) {
                    selectedCategoryIndex = idx
                }
            } onDelete: { category in
                pendingDeleteCategory = category
            }
        }
    }

    private var mineBarRow: some View {
        HStack(spacing: 8) {
            NoKeyboardURLField(
                text: $vm.urlText,
                placeholder: vm.errorMessage ?? "Paste a video URL",
                placeholderIsError: vm.errorMessage != nil
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 40, maxHeight: 40)
            .fixedSize(horizontal: false, vertical: true)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                lightHaptic()
                Task { await vm.mine() }
            } label: {
                HStack(spacing: 6) {
                    if vm.isLoading { ProgressView().tint(.white) }
                    Text(vm.isLoading ? "Mining..." : "Mine")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    if !vm.isLoading {
                        Image(systemName: "bolt")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
            }
            .buttonStyle(NarrowActionButtonStyle(accentColor: accentColor))
            .disabled(vm.isLoading)

            Button {
                lightHaptic()
                withAnimation(.easeInOut(duration: 0.25)) { isAddCategoryExpanded.toggle() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .rotationEffect(.degrees(isAddCategoryExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.25), value: isAddCategoryExpanded)
            }
            .buttonStyle(CapsuleToggleButtonStyle())
        }
    }

    private var searchBarRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(accentColor.opacity(0.8))

                TextField("Search transcripts", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .foregroundColor(.white)
                    .onChange(of: searchText) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            selectAllCategory()
                        }
                    }

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 40, maxHeight: 40)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    searchRowIndex = 0
                }
                searchText = ""
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
    }

    private func selectAllCategory() {
        guard let allIndex = categories.firstIndex(where: { $0.title == "All" }) else { return }
        selectedCategoryIndex = allIndex
        selectedCategoryId = categories[allIndex].id
        scrollProgress = CGFloat(allIndex)
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clipsForCategory(_ category: Category) -> [Clip] {
        let baseClips = category.title == "All"
            ? clips
            : clips.filter { $0.category == category.title }
        let trimmedSearch = trimmedSearchText
        if trimmedSearch.isEmpty {
            return baseClips
        }
        if category.title == "All" {
            let query = trimmedSearch.lowercased()
            return baseClips.filter { $0.transcript.lowercased().contains(query) }
        }
        return []
    }

    private var pagerView: some View {
        SwipePagingView(
            pages: categories,
            scrollProgress: $scrollProgress,
            selectedIndex: $selectedCategoryIndex
        ) { _, category in
            ScrollView {
                let pageClips = clipsForCategory(category)
                let trimmedSearch = trimmedSearchText
                VStack(spacing: 12) {
                        if category.title == "All" && pageClips.isEmpty {
                            if trimmedSearch.isEmpty {
                                EmptyClipPlaceholder()
                            } else {
                                SearchEmptyPlaceholder()
                            }
                        }
                        ForEach(Array(pageClips.enumerated()), id: \.element.id) { clipIndex, clip in
                            let clipNumber = pageClips.count - clipIndex
                            ClipCard(
                                clipNumber: clipNumber,
                                clip: clip,
                                categories: categoriesStore.customCategories + categoriesStore.defaultCategories,
                                onSelectCategory: { cat in onSelectCategory(clip, cat) },
                                onExpand: {
                                    selectedClip = clip
                                    selectedClipNumber = clipNumber
                                },
                                onDelete: {
                                    guard let uid = userId else { return }
                                    Task {
                                        do {
                                            try await clipsStore.deleteClip(userId: uid, clipId: clip.id)
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
                if let uid = userId {
                    clipsStore.startListening(userId: uid)
                    categoriesStore.startListening(userId: uid)
                }
            }
        }
    }

    private struct EmptyClipPlaceholder: View {
        @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
        private var outlineColor: Color { ThemeColors.color(from: themeAccent).opacity(0.9) }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Mine a clip to generate feed!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(outlineColor, lineWidth: 1.2)
            )
            .cornerRadius(16)
        }
    }

    private struct SearchEmptyPlaceholder: View {
        @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
        private var outlineColor: Color { ThemeColors.color(from: themeAccent).opacity(0.9) }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("No matching clips found.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(outlineColor, lineWidth: 1.2)
            )
            .cornerRadius(16)
        }
    }

    private func deleteCategory(named name: String) async {
        guard let uid = userId else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let db = Firestore.firestore()
        do {
            let clipsSnapshot = try await db
                .collection("users")
                .document(uid)
                .collection("clips")
                .whereField("category", isEqualTo: trimmed)
                .getDocuments()

            for doc in clipsSnapshot.documents {
                try await doc.reference.updateData(["category": "Other"])
            }

            let snapshot = try await db
                .collection("users")
                .document(uid)
                .collection("categories")
                .whereField("name", isEqualTo: trimmed)
                .getDocuments()

            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
        } catch {
            print("Delete category error:", error)
        }
    }
}

// MARK: - Swipe pager with progress
private struct PagerOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct SwipePagingView<Page, Content: View>: View {
    let pages: [Page]
    @Binding var scrollProgress: CGFloat
    @Binding var selectedIndex: Int
    @ViewBuilder let content: (Int, Page) -> Content

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            content(index, page)
                                .frame(width: geo.size.width)
                                .id(index)
                        }
                    }
                    .background(
                        GeometryReader { inner in
                            Color.clear
                                .preference(key: PagerOffsetKey.self, value: inner.frame(in: .named("Pager")).minX)
                        }
                    )
                }
                .coordinateSpace(name: "Pager")
                .pagingIfAvailable()
                .onChange(of: selectedIndex) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .onPreferenceChange(PagerOffsetKey.self) { minX in
                    let width = max(1, geo.size.width)
                    let progress = -minX / width
                    scrollProgress = max(0, min(progress, CGFloat(max(0, pages.count - 1))))
                }
            }
        }
    }
}

private struct PagingIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .scrollTargetLayout()
                .scrollTargetBehavior(.paging)
        } else {
            content
        }
    }
}

private extension View {
    func pagingIfAvailable() -> some View {
        self.modifier(PagingIfAvailable())
    }
}

private struct NarrowActionButtonStyle: ButtonStyle {
    let accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 112, height: 40)
            .background(Color.white.opacity(0.08))
            .foregroundColor(accentColor)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct CapsuleToggleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 40, height: 40)
            .background(Color.clear)
            .foregroundColor(.white.opacity(0.7))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ActionButtonStyle: ButtonStyle {
    let accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 160, height: 40)
            .background(Color.white.opacity(0.08))
            .foregroundColor(accentColor)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// URL field that keeps cursor + paste (long-press) but never shows the keyboard.
// Wrapper so the URL field doesn't expand layout when text is long (no intrinsic width).
private final class URLFieldContainer: UIView {
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 40)
    }
}

private struct NoKeyboardURLField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var placeholderIsError: Bool

    func makeUIView(context: Context) -> UIView {
        let container = URLFieldContainer()
        container.backgroundColor = .clear

        let field = UITextField()
        field.delegate = context.coordinator
        field.inputView = UIView()
        field.inputAccessoryView = nil
        field.keyboardType = .URL
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.font = .systemFont(ofSize: 14)
        field.textColor = .white
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.contentVerticalAlignment = .center
        field.adjustsFontSizeToFitWidth = false
        field.clearsOnInsertion = false
        field.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(field)

        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            field.topAnchor.constraint(equalTo: container.topAnchor),
            field.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        context.coordinator.field = field
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let field = context.coordinator.field else { return }
        if field.text != text {
            field.text = text
        }
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: placeholderIsError ? UIColor.systemRed : UIColor.white.withAlphaComponent(0.4)]
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NoKeyboardURLField
        weak var field: UITextField?
        init(_ parent: NoKeyboardURLField) { self.parent = parent }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
}

