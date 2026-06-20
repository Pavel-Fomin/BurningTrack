//
//  RenameTrackListContainer.swift
//  TrackList
//
//  UI-контейнер экрана переименования треклиста.
//
//  Роль контейнера:
//  - владеет состоянием формы (name)
//  - собирает состояние rename sheet-flow
//  - передаёт действия в RenameTrackListActionHandler
//
//  Архитектурные принципы:
//  - контейнер не содержит визуальной разметки формы
//  - контейнер не рисует TextField напрямую
//  - контейнер является аналогом UIViewController в UIKit
//  - RenameTrackListSheet — чистый UI-компонент без логики
//
//  Created by Pavel Fomin on 21.01.2026.
//

import SwiftUI
import Foundation

struct RenameTrackListContainer: View {

    /// Данные, переданные через SheetManager при открытии sheet’а.
    let data: RenameTrackListSheetData

    /// Локальное состояние формы — источник истины
    @State private var name: String

    init(data: RenameTrackListSheetData) {
        self.data = data
        self._name = State(initialValue: data.currentName)
    }

    // MARK: - UI

    var body: some View {
        let state = RenameTrackListStateBuilder().build(name: name)
        let actionHandler = RenameTrackListActionHandler(
            trackListId: data.trackListId,
            name: state.name,
            onNameChanged: { newName in
                name = newName
            }
        )

        RenameTrackListSheet(
            name: Binding(
                get: { name },
                set: { newName in
                    actionHandler.handle(.nameChanged(newName))
                }
            ),
            canSubmit: state.canSubmit,
            onSubmit: {
                actionHandler.handle(.submit)
            },
            onCancel: {
                actionHandler.handle(.cancel)
            }
        )
    }
}
