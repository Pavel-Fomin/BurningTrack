//
//  SwipeActionModifier.swift
//  TrackList
//
//  Модификатор свайпа
//
//  Created by Pavel Fomin on 17.07.2025.
//

import Foundation
import SwiftUI


// MARK: - Тип отображения свайпа

enum SwipeActionLabelType {
    case iconOnly
    case textOnly
    case iconAndText
}

// MARK: - Структура кастомного свайпа

struct CustomSwipeAction: Identifiable {
    let id = UUID()
    let label: String
    let systemImage: String
    let role: ButtonRole?
    let tint: Color
    let handler: () -> Void
    let labelType: SwipeActionLabelType
}

// MARK: - ViewModifier для левых и правых свайпов

struct SwipeActionModifier: ViewModifier {
    let swipeActionsLeft: [CustomSwipeAction]
    let swipeActionsRight: [CustomSwipeAction]

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                ForEach(swipeActionsRight) { action in
                    Button(role: action.role) {
                        action.handler()
                    } label: {
                        swipeLabel(for: action)
                    }
                    .tint(action.tint)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                ForEach(swipeActionsLeft) { action in
                    Button(role: action.role) {
                        action.handler()
                    } label: {
                        swipeLabel(for: action)
                    }
                    .tint(action.tint)
                }
            }
    }

    // Выводит лейбл для свайпа на основе `labelType`
    @ViewBuilder
    private func swipeLabel(for action: CustomSwipeAction) -> some View {
        switch action.labelType {
        case .iconOnly:
            Image(systemName: action.systemImage)
        case .textOnly:
            Text(action.label)
        case .iconAndText:
            Label(action.label, systemImage: action.systemImage)
        }
    }
}


// MARK: - View-расширитель

extension View {
    
    // Добавляет кастомные свайпы к любой вью
    func customSwipeActions(
            swipeActionsLeft: [CustomSwipeAction] = [],
            swipeActionsRight: [CustomSwipeAction] = []
        ) -> some View {
            modifier(SwipeActionModifier(
                swipeActionsLeft: swipeActionsLeft,
                swipeActionsRight: swipeActionsRight
            ))
        }
    }
