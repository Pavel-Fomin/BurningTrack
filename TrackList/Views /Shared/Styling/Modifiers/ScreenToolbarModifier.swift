//
//  ScreenToolbarModifier.swift
//  TrackList
//
//  Базовый модификатор тулбара для всех экранов.
//
//  - заголовок (principal)
//  - подзаголовок (опционально)
//  - общий стиль
//  - leading-зону
//
//  Created by Pavel Fomin on 09.11.2025.
//

import SwiftUI

struct ScreenToolbarModifier<Leading: View>: ViewModifier {

    let title: String
    let subtitle: String?
    let isTitleSecondary: Bool
    let leading: () -> Leading

    init(
        title: String,
        subtitle: String? = nil,
        isTitleSecondary: Bool = false,
        @ViewBuilder leading: @escaping () -> Leading
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isTitleSecondary = isTitleSecondary
        self.leading = leading
    }
    
    // MARK: - UI
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                
                /// Заголовок + подзаголовок
                ToolbarItem(placement: .principal) {
                    VStack(alignment: .leading, spacing: 2) {
                        
                        /// Мультиселект. Заголовок
                        if isTitleSecondary, let subtitle {
                            Text(title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)

                            /// Мультиселект. Подзаголовок
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            
                        } else {
                            
                            /// Обычный режим. Заголовок
                            Text(title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)

                            /// Обычный режим. Подзаголовок
                            if let subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                }

                /// Левая зона
                ToolbarItem(placement: .topBarLeading) {
                    leading()
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarRole(.editor)
    }
}

// MARK: - View extension

extension View {
    
    func screenToolbar<Leading: View>(
        title: String,
        subtitle: String? = nil,
        isTitleSecondary: Bool = false,
        @ViewBuilder leading: @escaping () -> Leading
    ) -> some View {
        self.modifier(
            ScreenToolbarModifier(
                title: title,
                subtitle: subtitle,
                isTitleSecondary: isTitleSecondary,
                leading: leading
            )
        )
    }
}
