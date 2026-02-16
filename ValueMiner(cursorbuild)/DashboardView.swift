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
import Foundation

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
    @State private var showAddClipSheet = false
    @State private var cachedOrderedCategoryTitles: [String] = []
    @State private var categoryIdMapCache: [String: UUID] = [:]
    @State private var pendingUserDefaultsWrite: DispatchWorkItem?
    @State private var pendingSearchUpdate: DispatchWorkItem?
    @State private var previousClipsCount: Int = 0
    @State private var plusOneOpacity: Double = 0
    @State private var plusOneOffset: CGFloat = 0
    @State private var didJustSaveFromInApp: Bool = false
    @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
    @AppStorage(ThemeColors.backgroundKey) private var themeBackground = ThemeColors.defaultBackground

    private var accentColor: Color { ThemeColors.color(from: themeAccent) }
    private var primaryText: Color { ThemeColors.primaryText(from: themeBackground) }
    private var backgroundColor: Color { ThemeColors.background(from: themeBackground) }

    private var orderedCategoryTitles: [String] {
        cachedOrderedCategoryTitles
    }

    private var totalCategoryCount: Int {
        orderedCategoryTitles.count
    }

    private var deletableTitles: Set<String> {
        let custom = Set(categoriesStore.customCategories)
        let deletableDefaults = Set(categoriesStore.activeDefaultCategories.filter { name in
            let lower = name.lowercased()
            return lower != "all" && lower != "other"
        })
        return custom.union(deletableDefaults)
    }


    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                headerView
                    .padding(.horizontal, 16)

                pagerView
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    lightHaptic()
                    showAddClipSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(accentColor)
                        .clipShape(Circle())
                        .overlay(
                            Group {
                                if themeBackground == "white" {
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.45), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    .clipShape(Circle())
                                }
                            }
                            .allowsHitTesting(false)
                        )
                        .shadow(color: Color.black.opacity(themeBackground == "white" ? 0.2 : 0), radius: themeBackground == "white" ? 10 : 0, x: 2, y: 5)
                        .shadow(color: Color.black.opacity(themeBackground == "white" ? 0.12 : 0), radius: themeBackground == "white" ? 16 : 0, x: 0, y: 6)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            updateCachedOrderedCategoryTitles()
            syncCategories(with: cachedOrderedCategoryTitles)
            previousClipsCount = clips.count
        }
        .onChange(of: clips.count) { oldCount, newCount in
            guard newCount == oldCount + 1 else {
                previousClipsCount = newCount
                return
            }
            previousClipsCount = newCount
            guard didJustSaveFromInApp else { return }
            didJustSaveFromInApp = false
            plusOneOpacity = 1
            plusOneOffset = 0
            withAnimation(.easeOut(duration: 0.95)) {
                plusOneOpacity = 0
                plusOneOffset = -26
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                plusOneOffset = 0
            }
        }
        .onChange(of: categoriesStore.customCategories) { _, _ in
            updateCachedOrderedCategoryTitles()
            syncCategories(with: cachedOrderedCategoryTitles)
        }
        .onChange(of: categoriesStore.defaultCategories) { _, _ in
            updateCachedOrderedCategoryTitles()
            syncCategories(with: cachedOrderedCategoryTitles)
        }
        .onChange(of: categoriesStore.removedDefaultCategories) { _, _ in
            updateCachedOrderedCategoryTitles()
            syncCategories(with: cachedOrderedCategoryTitles)
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
                    .cornerRadius(ThemeColors.inputAndButtonCornerRadius)
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
                .presentationDetents([.fraction(0.9)])
        }
        .sheet(isPresented: $showAddClipSheet) {
            addClipSheetContent
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

    private func updateCachedOrderedCategoryTitles() {
        let allCategory = "All"
        let otherCategory = "Other"
        let middleDefaults = categoriesStore.activeDefaultCategories.filter { $0 != "All" && $0 != "Other" }
        cachedOrderedCategoryTitles = [allCategory] + categoriesStore.customCategories + middleDefaults + [otherCategory]
    }
    
    private func syncCategories(with titles: [String]) {
        guard !titles.isEmpty else {
            categories = []
            selectedCategoryId = nil
            selectedCategoryIndex = 0
            return
        }

        // Load category ID map from UserDefaults once
        if categoryIdMapCache.isEmpty {
            let mapKey = "category_id_map_\(userId ?? "anon")"
            if let map = UserDefaults.standard.dictionary(forKey: mapKey) as? [String: String] {
                for (title, uuidString) in map {
                    if let uuid = UUID(uuidString: uuidString) {
                        categoryIdMapCache[title] = uuid
                    }
                }
            }
        }

        // Build the list in the exact order of titles, preserving UUIDs
        var newList: [Category] = []
        var needsUserDefaultsUpdate = false
        
        for title in titles {
            // Try to find existing category with same title to preserve its UUID
            if let existing = categories.first(where: { $0.title == title }) {
                newList.append(existing)
            } else {
                // Check cache first, then UserDefaults
                let uuid: UUID
                if let cached = categoryIdMapCache[title] {
                    uuid = cached
                } else {
                    uuid = UUID()
                    categoryIdMapCache[title] = uuid 
                    needsUserDefaultsUpdate = true
                }
                newList.append(Category(id: uuid, title: title))
            }
        }

        categories = newList
        
        // Debounce UserDefaults writes
        if needsUserDefaultsUpdate {
            pendingUserDefaultsWrite?.cancel()
            let userIdValue = userId ?? "anon"
            let mapToSave = categoryIdMapCache.mapValues { $0.uuidString }
            let workItem = DispatchWorkItem {
                let mapKey = "category_id_map_\(userIdValue)"
                UserDefaults.standard.set(mapToSave, forKey: mapKey)
            }
            pendingUserDefaultsWrite = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        }
        
        // Persist order to UserDefaults (debounced)
        pendingUserDefaultsWrite?.cancel()
        let userIdValue = userId ?? "anon"
        let categoryIds = newList.map { $0.id.uuidString }
        let persistenceWorkItem = DispatchWorkItem {
            let persistenceKey = "category_bar_order_\(userIdValue)"
            UserDefaults.standard.set(categoryIds, forKey: persistenceKey)
        }
        pendingUserDefaultsWrite = persistenceWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: persistenceWorkItem)

        if selectedCategoryId == nil || !categories.contains(where: { $0.id == selectedCategoryId }) {
            selectedCategoryId = categories.first?.id
            selectedCategoryIndex = 0
        }
    }

    private func idForTitle(_ title: String) -> UUID {
        if let cached = categoryIdMapCache[title] {
            return cached
        }
        let newId = UUID()
        categoryIdMapCache[title] = newId
        return newId
    }

    private static let lightHapticGenerator = UIImpactFeedbackGenerator(style: .light)
    private func lightHaptic() {
        Self.lightHapticGenerator.prepare()
        Self.lightHapticGenerator.impactOccurred()
    }

    private func clampCategoryName(_ value: String) -> String {
        let maxLength = 20
        if value.count <= maxLength { return value }
        return String(value.prefix(maxLength))
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                HStack(spacing: 10) {
                    Image("DashboardLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                    Text("Your Clips.")
                        .font(.title2).bold()
                        .foregroundColor(primaryText)
                    Spacer()
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(searchRowIndex == 0 ? accentColor : primaryText.opacity(0.3))
                        .frame(width: 5, height: 5)
                    Circle()
                        .fill(searchRowIndex == 1 ? accentColor : primaryText.opacity(0.3))
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
            .background(backgroundColor)
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
                        .foregroundColor(primaryText.opacity(0.4))
                )
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 14))
                    .foregroundColor(primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .glassBarStyle(themeBackground: themeBackground, strokeColor: primaryText)
                    .onChange(of: newCategoryName) { _, newValue in
                        newCategoryName = clampCategoryName(newValue)
                    }
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
                .buttonStyle(ActionButtonStyle(accentColor: accentColor, primaryText: primaryText, themeBackground: themeBackground))
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
        .overlay(alignment: .bottomLeading) {
            Text("+1")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(red: 0.2, green: 0.72, blue: 0.35))
                .opacity(plusOneOpacity)
                .offset(y: plusOneOffset)
                .padding(.leading, 44)
                .padding(.bottom, 18)
                .allowsHitTesting(false)
        }
    }

    private var addClipSheetContent: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Text("Add New Clip")
                        .font(.title2.bold())
                        .foregroundColor(primaryText)
                    Spacer()
                    Button(action: { showAddClipSheet = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(primaryText.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(ThemeColors.glassCardBackground(from: themeBackground))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(themeBackground == "white" ? 0.06 : 0), radius: themeBackground == "white" ? 3 : 0, x: 0, y: 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

            NoKeyboardURLField(
                text: $vm.urlText,
                placeholder: vm.errorMessage ?? "Paste a clip URL",
                placeholderIsError: vm.errorMessage != nil,
                textColor: ThemeColors.primaryTextUI(from: themeBackground)
            )
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(height: 44)
                .glassBarStyle(themeBackground: themeBackground, strokeColor: primaryText)
                .padding(.horizontal, 20)

                if let info = vm.infoMessage {
                    Text(info)
                        .font(.footnote)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                }

                Button {
                    lightHaptic()
                    Task {
                        await vm.mine()
                        if vm.urlText.isEmpty && !vm.isLoading {
                            didJustSaveFromInApp = true
                            withAnimation(.easeOut(duration: 0.25)) {
                                showAddClipSheet = false
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if vm.isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                            Text("Saving...")
                                .font(.system(size: 16, weight: .semibold))
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Add Clip")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accentColor)
                    .cornerRadius(ThemeColors.inputAndButtonCornerRadius)
                    .glassButtonHighlight(themeBackground: themeBackground)
                    .shadow(color: Color.black.opacity(ThemeColors.shadowOpacityButton(from: themeBackground)), radius: themeBackground == "white" ? 6 : 2, x: 1, y: 3)
                }
                .disabled(vm.isLoading)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .presentationDetents([.height(240)])
    }

    private var mineBarRow: some View {
        HStack(spacing: 8) {
            NoKeyboardURLField(
                text: $vm.urlText,
                placeholder: vm.errorMessage ?? "Paste a clip URL",
                placeholderIsError: vm.errorMessage != nil,
                textColor: ThemeColors.primaryTextUI(from: themeBackground)
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 40, maxHeight: 40)
            .fixedSize(horizontal: false, vertical: true)
            .glassBarStyle(themeBackground: themeBackground, strokeColor: primaryText)

            Button {
                lightHaptic()
                Task {
                    await vm.mine()
                    if vm.urlText.isEmpty && !vm.isLoading {
                        didJustSaveFromInApp = true
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if vm.isLoading { ProgressView().tint(accentColor) }
                    Text(vm.isLoading ? "Saving..." : "Save")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    if !vm.isLoading {
                        Image(systemName: "bolt")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
            }
            .buttonStyle(NarrowActionButtonStyle(accentColor: accentColor, primaryText: primaryText, themeBackground: themeBackground))
            .disabled(vm.isLoading)

            Button {
                lightHaptic()
                withAnimation(.easeInOut(duration: 0.25)) { isAddCategoryExpanded.toggle() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(primaryText.opacity(0.7))
                    .rotationEffect(.degrees(isAddCategoryExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.25), value: isAddCategoryExpanded)
            }
            .buttonStyle(CapsuleToggleButtonStyle(primaryText: primaryText))
        }
    }

    private var searchBarRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(accentColor.opacity(0.8))

                TextField("", text: $searchText, prompt: Text("Search clips/notes").foregroundColor(primaryText.opacity(themeBackground == "white" ? 0.65 : 0.6)))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .foregroundColor(primaryText)
                    .onChange(of: searchText) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            selectAllCategory()
                        }
                    }

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(primaryText.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 40, maxHeight: 40)
            .glassBarStyle(themeBackground: themeBackground, strokeColor: primaryText)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    searchRowIndex = 0
                }
                searchText = ""
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(primaryText.opacity(0.8))
                    .padding(10)
                    .frame(width: 40, height: 40)
                    .background(ThemeColors.glassCardBackground(from: themeBackground))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(themeBackground == "white" ? 0.06 : 0), radius: themeBackground == "white" ? 4 : 0, x: 0, y: 2)
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
        let query = trimmedSearch.lowercased()
        return baseClips.filter { clip in
            clip.transcript.lowercased().contains(query)
                || (clip.personalNotes?.lowercased().contains(query) ?? false)
        }
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
                LazyVStack(spacing: 12) {
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
                                categories: cachedOrderedCategoryTitles,
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
                                },
                                onSaveNotes: { notes in
                                    guard let uid = userId else { return }
                                    Task {
                                        try? await clipsStore.updateNotes(userId: uid, clipId: clip.id, notes: notes)
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
        @AppStorage(ThemeColors.backgroundKey) private var themeBackground = ThemeColors.defaultBackground
        private var outlineColor: Color { ThemeColors.color(from: themeAccent).opacity(themeBackground == "white" ? 0.75 : 0.2) }
        private var primaryText: Color { ThemeColors.primaryText(from: themeBackground) }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Mine a clip to generate feed!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(primaryText.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ThemeColors.glassCardBackground(from: themeBackground))
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
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(outlineColor, lineWidth: ThemeColors.feedCardAndProfileBoxBorderWidth)
            )
            .cornerRadius(16)
            .cardDepthShadow(themeBackground: themeBackground)
        }
    }

    private struct SearchEmptyPlaceholder: View {
        @AppStorage("themeAccent") private var themeAccent = ThemeColors.defaultAccent
        @AppStorage(ThemeColors.backgroundKey) private var themeBackground = ThemeColors.defaultBackground
        private var outlineColor: Color { ThemeColors.color(from: themeAccent).opacity(themeBackground == "white" ? 0.75 : 0.2) }
        private var primaryText: Color { ThemeColors.primaryText(from: themeBackground) }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("No matching clips found.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(primaryText.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ThemeColors.glassCardBackground(from: themeBackground))
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
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(outlineColor, lineWidth: ThemeColors.feedCardAndProfileBoxBorderWidth)
            )
            .cornerRadius(16)
            .cardDepthShadow(themeBackground: themeBackground)
        }
    }

    private func deleteCategory(named name: String) async {
        guard let uid = userId else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let lower = trimmed.lowercased()
        let isDefaultCategory = categoriesStore.defaultCategories.contains(where: { $0.lowercased() == lower })

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

            if isDefaultCategory {
                categoriesStore.removeDefaultCategory(name: trimmed)
            } else {
                let snapshot = try await db
                    .collection("users")
                    .document(uid)
                    .collection("categories")
                    .whereField("name", isEqualTo: trimmed)
                    .getDocuments()

                for doc in snapshot.documents {
                    try await doc.reference.delete()
                }
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
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
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
    let primaryText: Color
    let themeBackground: String

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 112, height: 40)
            .background(themeBackground == "white" ? accentColor : primaryText.opacity(ThemeColors.inputFillOpacity(from: themeBackground)))
            .foregroundColor(themeBackground == "white" ? (accentColor == .white ? .black : .white) : accentColor)
            .cornerRadius(ThemeColors.inputAndButtonCornerRadius)
            .glassButtonHighlight(themeBackground: themeBackground)
            .shadow(color: Color.black.opacity(ThemeColors.shadowOpacityButton(from: themeBackground)), radius: themeBackground == "white" ? 6 : 2, x: 1, y: 3)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct CapsuleToggleButtonStyle: ButtonStyle {
    let primaryText: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 40, height: 40)
            .background(Color.clear)
            .foregroundColor(primaryText.opacity(0.7))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ActionButtonStyle: ButtonStyle {
    let accentColor: Color
    let primaryText: Color
    let themeBackground: String

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 160, height: 40)
            .background(themeBackground == "white" ? accentColor : primaryText.opacity(ThemeColors.inputFillOpacity(from: themeBackground)))
            .foregroundColor(themeBackground == "white" ? (accentColor == .white ? .black : .white) : accentColor)
            .cornerRadius(ThemeColors.inputAndButtonCornerRadius)
            .glassButtonHighlight(themeBackground: themeBackground)
            .shadow(color: Color.black.opacity(ThemeColors.shadowOpacityButton(from: themeBackground)), radius: themeBackground == "white" ? 6 : 2, x: 1, y: 3)
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
    var textColor: UIColor = .white

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
        field.textColor = textColor
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.contentVerticalAlignment = .center
        field.adjustsFontSizeToFitWidth = false
        field.clearsOnInsertion = false
        field.clearButtonMode = .whileEditing
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
        field.textColor = textColor
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: placeholderIsError ? UIColor.systemRed : textColor.withAlphaComponent(0.4)]
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

