//
//  ReorderableCategoryBar.swift
//  ValueMiner(cursorbuild)
//
//  Created by Michael Alfieri on 1/27/26.
//
import SwiftUI
import UIKit

// MARK: - Category model
struct Category: Identifiable, Equatable {
    let id: UUID
    var title: String
}

// MARK: - SwiftUI wrapper
struct ReorderableCategoryBar: View {
    @Binding var categories: [Category]
    @Binding var selectedCategoryId: UUID?
    @State private var isEditing = false

    let persistenceKey: String
    let deletableTitles: Set<String>
    let countProvider: ((Category) -> Int)?
    let onSelect: ((Category) -> Void)?
    let onDelete: ((Category) -> Void)?

    init(
        categories: Binding<[Category]>,
        selectedCategoryId: Binding<UUID?>,
        persistenceKey: String,
        deletableTitles: Set<String> = [],
        countProvider: ((Category) -> Int)? = nil,
        onSelect: ((Category) -> Void)? = nil,
        onDelete: ((Category) -> Void)? = nil
    ) {
        self._categories = categories
        self._selectedCategoryId = selectedCategoryId
        self.persistenceKey = persistenceKey
        self.deletableTitles = deletableTitles
        self.countProvider = countProvider
        self.onSelect = onSelect
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                HStack {
                    Spacer()
                    Button("Done") { isEditing = false }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.trailing, 4)
                }
            }

            ReorderableCategoryBarRepresentable(
                categories: $categories,
                selectedCategoryId: $selectedCategoryId,
                isEditing: $isEditing,
                persistenceKey: persistenceKey,
                deletableTitles: deletableTitles,
                countProvider: countProvider,
                onSelect: onSelect,
                onDelete: onDelete
            )
            .frame(height: 48)
        }
    }
}

// MARK: - UIViewRepresentable
struct ReorderableCategoryBarRepresentable: UIViewRepresentable {
    @Binding var categories: [Category]
    @Binding var selectedCategoryId: UUID?
    @Binding var isEditing: Bool

    let persistenceKey: String
    let deletableTitles: Set<String>
    let countProvider: ((Category) -> Int)?
    let onSelect: ((Category) -> Void)?
    let onDelete: ((Category) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(CategoryPillCell.self, forCellWithReuseIdentifier: CategoryPillCell.reuseID)

        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.4
        collectionView.addGestureRecognizer(longPress)

        context.coordinator.collectionView = collectionView
        return collectionView
    }

    func updateUIView(_ uiView: UICollectionView, context: Context) {
        context.coordinator.parent = self

        applyPersistedOrderIfNeeded()

        if context.coordinator.isEditing != isEditing {
            context.coordinator.isEditing = isEditing
            isEditing ? context.coordinator.startWiggle() : context.coordinator.stopWiggle()
        }

        uiView.reloadData()
    }

    private func applyPersistedOrderIfNeeded() {
        let saved = UserDefaults.standard.array(forKey: persistenceKey) as? [String] ?? []
        guard !saved.isEmpty else { return }
        let order = saved.compactMap { UUID(uuidString: $0) }
        let ordered = CategoryOrder.apply(order: order, to: categories)
        categories = ordered
        CategoryOrder.persist(order: ordered.map(\.id), key: persistenceKey)
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        var parent: ReorderableCategoryBarRepresentable
        weak var collectionView: UICollectionView?
        var isEditing = false
        private let tapFeedback = UIImpactFeedbackGenerator(style: .light)
        private let editFeedback = UIImpactFeedbackGenerator(style: .medium)

        init(parent: ReorderableCategoryBarRepresentable) {
            self.parent = parent
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            parent.categories.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CategoryPillCell.reuseID, for: indexPath) as! CategoryPillCell
            let category = parent.categories[indexPath.item]
            let isSelected = category.id == parent.selectedCategoryId
            let count = parent.countProvider?(category)
            let isLocked = isLockedCategory(category)
            let isDeletable = parent.deletableTitles.contains(category.title) && !isLocked
            cell.onDeleteTap = { [weak self] in
                self?.parent.onDelete?(category)
            }
            cell.configure(
                title: category.title,
                count: count,
                isSelected: isSelected,
                isEditing: isEditing,
                isLocked: isLocked,
                isDeletable: isDeletable
            )
            return cell
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            tapFeedback.prepare()
            tapFeedback.impactOccurred()
            let category = parent.categories[indexPath.item]
            parent.selectedCategoryId = category.id
            parent.onSelect?(category)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
            collectionView.reloadData()
        }

        func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
            !isLockedCategory(parent.categories[indexPath.item])
        }

        func collectionView(_ collectionView: UICollectionView, targetIndexPathForMoveFromItemAt originalIndexPath: IndexPath, toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
            guard collectionView.numberOfItems(inSection: proposedIndexPath.section) > 1 else {
                return originalIndexPath
            }
            return proposedIndexPath.item == 0 ? IndexPath(item: 1, section: proposedIndexPath.section) : proposedIndexPath
        }

        func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
            var items = parent.categories
            let moved = items.remove(at: sourceIndexPath.item)
            items.insert(moved, at: destinationIndexPath.item)
            if let allIndex = items.firstIndex(where: isLockedCategory), allIndex != 0 {
                let locked = items.remove(at: allIndex)
                items.insert(locked, at: 0)
            }
            parent.categories = items
            CategoryOrder.persist(order: items.map { $0.id }, key: parent.persistenceKey)
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let collectionView = collectionView else { return }
            let location = gesture.location(in: collectionView)

            switch gesture.state {
            case .began:
                guard let indexPath = collectionView.indexPathForItem(at: location) else { return }
                editFeedback.prepare()
                editFeedback.impactOccurred()
                if isLockedCategory(parent.categories[indexPath.item]) {
                    if !isEditing {
                        parent.isEditing = true
                        isEditing = true
                        startWiggle()
                    }
                    return
                }
                if !isEditing {
                    parent.isEditing = true
                    isEditing = true
                    startWiggle()
                }
                collectionView.beginInteractiveMovementForItem(at: indexPath)
                liftCell(at: indexPath, lifted: true)
            case .changed:
                collectionView.updateInteractiveMovementTargetPosition(location)
            case .ended:
                collectionView.endInteractiveMovement()
                if let indexPath = collectionView.indexPathForItem(at: location) {
                    liftCell(at: indexPath, lifted: false)
                }
            default:
                collectionView.cancelInteractiveMovement()
                if let indexPath = collectionView.indexPathForItem(at: location) {
                    liftCell(at: indexPath, lifted: false)
                }
            }
        }

        func startWiggle() {
            guard let collectionView else { return }
            for cell in collectionView.visibleCells {
                if let pill = cell as? CategoryPillCell, !pill.isLocked {
                    pill.startWiggle()
                }
            }
        }

        func stopWiggle() {
            guard let collectionView else { return }
            for cell in collectionView.visibleCells {
                (cell as? CategoryPillCell)?.stopWiggle()
            }
        }

        private func liftCell(at indexPath: IndexPath, lifted: Bool) {
            guard let cell = collectionView?.cellForItem(at: indexPath) else { return }
            UIView.animate(withDuration: 0.12) {
                cell.transform = lifted ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
                cell.layer.shadowOpacity = lifted ? 0.25 : 0
                cell.layer.shadowRadius = lifted ? 8 : 0
                cell.layer.shadowOffset = CGSize(width: 0, height: 3)
            }
        }

        private func isLockedCategory(_ category: Category) -> Bool {
            category.title.lowercased() == "all"
        }
    }
}

// MARK: - Cell
final class CategoryPillCell: UICollectionViewCell {
    static let reuseID = "CategoryPillCell"

    private let label = UILabel()
    private let container = UIView()
    private let deleteButton = UIButton(type: .system)
    private(set) var isLocked = false
    var onDeleteTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        contentView.backgroundColor = .clear
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer.cornerRadius = 18
        if #available(iOS 13.0, *) {
            container.layer.cornerCurve = .continuous
        }
        container.layer.masksToBounds = true
        container.backgroundColor = UIColor.white.withAlphaComponent(0.08)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = themeAccentColor()

        container.addSubview(label)
        contentView.addSubview(container)
        contentView.addSubview(deleteButton)

        let minusImage = UIImage(systemName: "minus")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 9, weight: .bold))
        deleteButton.setImage(minusImage, for: .normal)
        deleteButton.tintColor = .white
        deleteButton.backgroundColor = .systemRed
        deleteButton.layer.cornerRadius = 8
        deleteButton.clipsToBounds = true
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.isHidden = true
        deleteButton.addTarget(self, action: #selector(handleDeleteTap), for: .touchUpInside)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 9),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -9),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 13),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -13),

            deleteButton.widthAnchor.constraint(equalToConstant: 16),
            deleteButton.heightAnchor.constraint(equalToConstant: 16),
            deleteButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -3),
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 3),
        ])
    }

    func configure(title: String, count: Int?, isSelected: Bool, isEditing: Bool, isLocked: Bool, isDeletable: Bool) {
        self.isLocked = isLocked
        let isAll = title.lowercased() == "all"
        let baseColor = isAll
            ? UIColor.systemGreen
            : themeAccentColor()
        let titleText = title.uppercased()
        if let count = count {
            let full = "\(titleText) (\(count))"
            let attr = NSMutableAttributedString(string: full, attributes: [
                .foregroundColor: baseColor,
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            ])
            let countRange = (full as NSString).range(of: "(\(count))")
            attr.addAttributes([
                .foregroundColor: baseColor.withAlphaComponent(0.6),
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            ], range: countRange)
            label.attributedText = attr
        } else {
            label.text = titleText
            label.textColor = baseColor
        }

        if isSelected {
            container.backgroundColor = baseColor.withAlphaComponent(0.25)
            label.textColor = .white
        } else {
            container.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        }

        deleteButton.isHidden = !(isEditing && isDeletable)

        if isEditing && !isLocked {
            startWiggle()
        } else {
            stopWiggle()
        }
    }

    private func themeAccentColor() -> UIColor {
        let raw = UserDefaults.standard.string(forKey: "themeAccent") ?? ThemeColors.defaultAccent
        return ThemeColors.uiColor(from: raw)
    }

    @objc private func handleDeleteTap() {
        onDeleteTap?()
    }

    func startWiggle() {
        guard layer.animation(forKey: "wiggle") == nil else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform.rotation")
        animation.values = [(-2.0).degreesToRadians, (2.0).degreesToRadians, (-2.0).degreesToRadians]
        animation.duration = 0.22
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        animation.beginTime = CACurrentMediaTime() + Double.random(in: 0...0.08)
        layer.add(animation, forKey: "wiggle")
    }

    func stopWiggle() {
        layer.removeAnimation(forKey: "wiggle")
        transform = .identity
    }
}

// MARK: - Order persistence
private enum CategoryOrder {
    static func persist(order: [UUID], key: String) {
        let ids = order.map { $0.uuidString }
        UserDefaults.standard.set(ids, forKey: key)
    }

    static func apply(order: [UUID], to categories: [Category]) -> [Category] {
        guard !order.isEmpty else { return categories }
        let map = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let ordered = order.compactMap { map[$0] }
        let remaining = categories.filter { !order.contains($0.id) }
        guard let first = ordered.first else { return ordered + remaining }
        let rest = ordered.dropFirst()
        return [first] + remaining + Array(rest)
    }
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
}
