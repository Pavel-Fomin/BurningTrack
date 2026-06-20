//
//  CreateTrackListContainer.swift
//  TrackList
//
//  Контейнер создания нового треклиста.
//
//  Created by Pavel Fomin on 30.04.2026.
//

import SwiftUI
import Foundation

struct CreateTrackListContainer: View {

    // MARK: - State

    /// Название нового треклиста.
    @State private var name = generateDefaultTrackListName()

    // MARK: - UI

    var body: some View {
        let state = CreateTrackListStateBuilder().build(name: name)
        let actionHandler = CreateTrackListActionHandler(
            name: state.name,
            onNameChanged: { newName in
                name = newName
            }
        )

        CreateTrackListSheet(
            name: Binding(
                get: { name },
                set: { newName in
                    actionHandler.handle(.nameChanged(newName))
                }
            ),
            canSubmit: state.canSubmit,
            onCreateEmpty: {
                actionHandler.handle(.createEmpty)
            },
            onAddTracks: {
                actionHandler.handle(.addTracks)
            },
            onCancel: {
                actionHandler.handle(.cancel)
            }
        )
    }
}
