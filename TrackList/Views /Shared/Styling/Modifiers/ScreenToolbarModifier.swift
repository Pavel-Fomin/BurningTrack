//
//  ScreenToolbarModifier.swift
//  TrackList
//
//  Базовый модификатор тулбара для всех экранов
//  Определяет общую структуру и оформление заголовка.
//
//  Created by Pavel Fomin on 09.11.2025.
//

import SwiftUI

struct ScreenToolbarModifier<Leading: View, Trailing: View>: ViewModifier {
    let title: String
    let leading: () -> Leading
    let trailing: () -> Trailing

    init(title: String,
         @ViewBuilder leading: @escaping () -> Leading,
         @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.leading = leading
        self.trailing = trailing
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                        .accessibilityAddTraits(.isHeader)
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    leading()
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    trailing()
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarRole(.editor)
    }
}

extension View {
    func screenToolbar<Leading: View, Trailing: View>(
        title: String,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) -> some View {
        self.modifier(ScreenToolbarModifier(title: title,
                                            leading: leading,
                                            trailing: trailing))
    }
}
