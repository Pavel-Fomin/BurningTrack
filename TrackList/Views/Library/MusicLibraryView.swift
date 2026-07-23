//
//  MusicLibraryView.swift
//  TrackList
//
//  Секция папок в корне фонотеки:
//  — показывает прикреплённые папки,
//  — по нажатию переходит в LibraryFolderView,
//  — не содержит собственный List и не смешивает папки с коллекцией.
//
//  Created by Pavel Fomin on 22.06.2025.
//

import SwiftUI

struct MusicLibraryView: View {

    // MARK: - Входные данные

    /// Готовое состояние корневого экрана фонотеки.
    let state: LibraryMasterScreenState
    /// Передаёт пользовательские действия обработчику экрана.
    let onAction: (LibraryMasterAction) -> Void

    var body: some View {
        folderSectionContent
        .onAppear {
            onAction(.onAppear)
        }
        // Первое подтверждение не допускает открепления папки сразу после свайпа.
        .alert(
            "Remove Folder?",
            isPresented: Binding(
                get: { state.showsDetachFolderConfirmation },
                set: { isPresented in
                    if isPresented == false {
                        onAction(.cancelDetachFolder)
                    }
                }
            )
        ) {
            Button("Remove", role: .destructive) {
                onAction(.confirmDetachFolder)
            }

            Button("Cancel", role: .cancel) {
                onAction(.cancelDetachFolder)
            }
        } message: {
            Text(
                "This folder will be removed from the library, "
                + "but the files on your device will remain unchanged."
            )
        }
        // Второе подтверждение показывается только после проверки активного трека.
        .alert(
            "Stop Playback to Remove Folder",
            isPresented: Binding(
                get: { state.folderContainsPlayingTrack },
                set: { isPresented in
                    if isPresented == false {
                        onAction(.cancelDetachFolder)
                    }
                }
            )
        ) {
            Button("Stop and Remove", role: .destructive) {
                onAction(.confirmStopAndDetachFolder)
            }

            Button("Close", role: .cancel) {
                onAction(.cancelDetachFolder)
            }
        } message: {
            Text("A track from this folder is currently playing.")
        }
    }

    // MARK: - Загрузка

    @ViewBuilder
    private var folderSectionContent: some View {
        if state.accessState == .booting {
            LibraryFoldersSkeletonView()

        } else {
            if state.isEmpty {
                emptyFoldersRow
            } else {
                ForEach(state.folders) { folder in
                    folderRow(folder)
                }
                // Ручное перемещение разрешено только для реальных прикреплённых папок.
                .onMove { source, destination in
                    onAction(.moveFolder(source, destination))
                }
            }

            // Строка добавления всегда остаётся после списка реальных папок.
            addFolderRow
        }
    }

    /// Показывает пустое состояние только для списка папок, не затрагивая виртуальные источники.
    private var emptyFoldersRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .foregroundColor(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("No Folders Added")
                    .foregroundColor(.primary)
                Text("Add a music folder to view local files.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    /// Строит строку прикреплённой папки без прямого доступа к менеджерам.
    private func folderRow(
        _ folder: LibraryMasterFolderRowState
    ) -> some View {
        LibraryFolderRowView(
            name: folder.name,
            isAttaching: folder.isAttaching
        ) {
            onAction(.openFolder(folder.id))
        }
        .swipeActions(edge: .trailing) {
            if folder.isAttaching == false {
                Button(role: .destructive) {
                    onAction(.requestDetachFolder(folder.id))
                } label: {
                    Image(systemName: "pin.slash.fill")
                }
            }
        }
    }

    /// Строит строку добавления новой папки в общий корневой список.
    private var addFolderRow: some View {
        Button {
            onAction(.addFolderTapped)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill.badge.plus")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                Text("Add Folder")
            }
            .padding(.vertical, 4)
        }
    }
}
