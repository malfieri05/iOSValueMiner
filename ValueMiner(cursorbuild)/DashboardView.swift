//
//  DashboardView.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/24/26.
//
import SwiftUI
import UIKit
import FirebaseFirestore

struct DashboardView: View {
    let clips: [Clip]
    @ObservedObject var clipsStore: ClipsStore
    @Binding var selectedClip: Clip?
    @ObservedObject var categoriesStore: CategoriesStore
    let userId: String?
    let onSelectCategory: (Clip, String) -> Void

    @State private var categories: [Category] = []
    @State private var selectedCategoryId: UUID? = nil
    @State private var selectedCategoryIndex: Int = 0
    @State private var scrollProgress: CGFloat = 0
    @State private var showingAddCategory = false
    @State private var newCategoryName: String = ""
    @State private var pendingDeleteCategory: Category?

    private var orderedCategoryTitles: [String] {
        let allCategory = categoriesStore.defaultCategories.first! // "All"
        let otherCategories = categoriesStore.defaultCategories.dropFirst().filter { $0 != "Other" }
        let otherCategory = "Other"
        return [allCategory] + otherCategories + categoriesStore.customCategories + [otherCategory]
    }

    private var totalCategoryCount: Int {
        orderedCategoryTitles.count
    }

    private var deletableTitles: Set<String> {
        Set(categoriesStore.customCategories)
    }

    var body: some View {
        ZStack {
            Color(red: 16/255, green: 18/255, blue: 32/255).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Mine.")
                        .font(.title2).bold()
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        TextField("New folder name", text: $newCategoryName)
                            .textInputAutocapitalization(.never)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        Button {
                            lightHaptic()
                            Task {
                                let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                                if let uid = userId, !name.isEmpty {
                                    try? await categoriesStore.addCategory(userId: uid, name: name)
                                    newCategoryName = ""
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Category")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("(\(totalCategoryCount))")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(Color(red: 164/255, green: 93/255, blue: 233/255).opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(Color(red: 164/255, green: 93/255, blue: 233/255))
                            .cornerRadius(12)
                        }
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || userId == nil)
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
                .padding(.horizontal, 16)

                SwipePagingView(
                    pages: categories,
                    scrollProgress: $scrollProgress,
                    selectedIndex: $selectedCategoryIndex
                ) { _, category in
                    let pageClips = category.title == "All" ? clips : clips.filter { $0.category == category.title }
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(Array(pageClips.enumerated()), id: \.element.id) { clipIndex, clip in
                                ClipCard(
                                    clipNumber: pageClips.count - clipIndex,
                                    clip: clip,
                                    categories: categoriesStore.defaultCategories.dropFirst() + categoriesStore.customCategories,
                                    onSelectCategory: { cat in onSelectCategory(clip, cat) },
                                    onExpand: { selectedClip = clip }
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
        .onChange(of: scrollProgress) { _, newProgress in
            let idx = Int(round(newProgress))
            if categories.indices.contains(idx) {
                selectedCategoryIndex = idx
                selectedCategoryId = categories[idx].id
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            VStack(spacing: 16) {
                Text("New folder name")
                    .font(.headline)
                TextField("Category name", text: $newCategoryName)
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                HStack {
                    Button("Cancel") { showingAddCategory = false }
                    Spacer()
                    Button("Add") {
                        Task {
                            let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
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

        var newList: [Category] = []
        let titleSet = Set(titles)

        for existing in categories where titleSet.contains(existing.title) {
            newList.append(existing)
        }

        for title in titles where !newList.contains(where: { $0.title == title }) {
            newList.append(Category(id: idForTitle(title), title: title))
        }

        categories = newList

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

    private func deleteCategory(named name: String) async {
        guard let uid = userId else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let db = Firestore.firestore()
        do {
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
