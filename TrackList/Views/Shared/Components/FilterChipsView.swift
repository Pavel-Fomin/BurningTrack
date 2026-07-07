//
//  FilterChipsView.swift
//  TrackList
//
//  Переиспользуемый компонент чипов фильтра с переносом строк.
//  Created by Pavel Fomin on 04.07.2026.
//

import SwiftUI

// Отображает готовые чипы фильтра и сообщает наружу о выборе элемента.
struct FilterChipsView<Item: Identifiable & Equatable>: View {
    let items: [Item]
    let selectedItem: Item?
    let title: (Item) -> String
    let detail: (Item) -> String?
    let onSelect: (Item) -> Void

    init(
        items: [Item],
        selectedItem: Item?,
        title: @escaping (Item) -> String,
        detail: @escaping (Item) -> String? = { _ in nil },
        onSelect: @escaping (Item) -> Void
    ) {
        self.items = items
        self.selectedItem = selectedItem
        self.title = title
        self.detail = detail
        self.onSelect = onSelect
    }

    var body: some View {
        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(items) { item in
                FilterChipButton(
                    title: title(item),
                    detail: detail(item),
                    isSelected: item == selectedItem,
                    onTap: {
                        onSelect(item)
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Кнопка одного чипа без знания о типе фильтра и его происхождении.
private struct FilterChipButton: View {
    let title: String
    let detail: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(title)
                    .fontWeight(.medium)

                if let detail {
                    Text(detail)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }
            .font(.subheadline)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(chipBackground)
            .overlay(chipBorder)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isSelected ? "Выбрано" : "")
    }

    /// Объединяет основной и дополнительный текст для VoiceOver.
    private var accessibilityLabel: String {
        guard let detail else { return title }
        return "\(title) \(detail)"
    }

    /// Фон выбранного чипа отделяет активный фильтр от остальных вариантов.
    private var chipBackground: some View {
        Capsule()
            .fill(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
    }

    /// Тонкая обводка нужна для светлой темы, где фон чипа близок к фону списка.
    private var chipBorder: some View {
        Capsule()
            .stroke(
                isSelected ? Color.accentColor : Color(.separator).opacity(0.35),
                lineWidth: 1
            )
    }
}

// Раскладывает дочерние элементы в несколько строк без горизонтального скролла.
struct FlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let arranged = arrangeSubviews(
            maxWidth: proposal.width,
            subviews: subviews
        )

        return CGSize(
            width: proposal.width ?? arranged.size.width,
            height: arranged.size.height
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let arranged = arrangeSubviews(
            maxWidth: bounds.width,
            subviews: subviews
        )

        for item in arranged.items {
            subviews[item.index].place(
                at: CGPoint(
                    x: bounds.minX + item.origin.x,
                    y: bounds.minY + item.origin.y
                ),
                proposal: ProposedViewSize(
                    width: item.size.width,
                    height: item.size.height
                )
            )
        }
    }

    /// Раскладывает элементы по строкам и переносит следующий элемент, когда ширины уже не хватает.
    private func arrangeSubviews(
        maxWidth: CGFloat?,
        subviews: Subviews
    ) -> (items: [FlowLayoutItem], size: CGSize) {
        let availableWidth = maxWidth ?? .greatestFiniteMagnitude
        var items: [FlowLayoutItem] = []
        var cursorX: CGFloat = 0
        var cursorY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var contentWidth: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextX = cursorX == 0 ? 0 : cursorX + horizontalSpacing

            if nextX + size.width > availableWidth,
               cursorX > 0 {
                cursorX = 0
                cursorY += rowHeight + verticalSpacing
                rowHeight = 0
            }

            let originX = cursorX == 0 ? 0 : cursorX + horizontalSpacing
            items.append(
                FlowLayoutItem(
                    index: index,
                    origin: CGPoint(x: originX, y: cursorY),
                    size: size
                )
            )

            cursorX = originX + size.width
            rowHeight = max(rowHeight, size.height)
            contentWidth = max(contentWidth, cursorX)
        }

        let contentHeight = items.isEmpty ? 0 : cursorY + rowHeight
        return (
            items,
            CGSize(
                width: contentWidth,
                height: contentHeight
            )
        )
    }
}

// Позиция одного элемента внутри переносимого layout.
private struct FlowLayoutItem {
    let index: Int
    let origin: CGPoint
    let size: CGSize
}
