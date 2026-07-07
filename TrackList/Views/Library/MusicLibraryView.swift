//
//  MusicLibraryView.swift
//  TrackList
//
//  Корневой экран фонотеки:
//  — показывает виртуальный источник купленных треков iTunes,
//  — показывает прикреплённые папки,
//  — по нажатию переходит в LibraryFolderView,
//  — не содержит логики вкладок,
//  — не использует старый route.
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
        Group {
            // MARK: - Загрузка при первом запуске
            if state.accessState == .booting {
                loadingView

            // MARK: - Нет прикреплённых папок
            } else if state.isEmpty {
                // В пустой фонотеке показываем доступные источники и состояние отсутствия папок.
                libraryRootList

            // MARK: - Папки есть → показываем корневой список
            } else {
                libraryRootList
            }
        }
        .onAppear {
            onAction(.onAppear)
        }
        .alert(
            state.detachAlert?.title ?? "",
            isPresented: Binding(
                get: { state.detachAlert != nil },
                set: { isPresented in
                    if isPresented == false {
                        onAction(.cancelDetachFolder)
                    }
                }
            )
        ) {
            Button("Остановить и открепить", role: .destructive) {
                onAction(.confirmStopAndDetachFolder)
            }

            Button("Закрыть", role: .cancel) {
                onAction(.cancelDetachFolder)
            }
        } message: {
            Text(state.detachAlert?.message ?? "")
        }
    }

    // MARK: - Загрузка

    private var loadingView: some View {
        VStack(spacing: 0) {
            LibraryFoldersSkeletonView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Корневой список фонотеки

    private var libraryRootList: some View {
        List {
            if state.showsPurchasedITunesSource {
                Section {
                    purchasedITunesRow
                }
            }

            Section {
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

                addFolderRow
            }
        }
    }

    /// Строит строку виртуального источника iTunes отдельно от реальных папок.
    private var purchasedITunesRow: some View {
        Button {
            onAction(.openPurchasedITunes)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text("Куплено в iTunes")
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    /// Показывает пустое состояние только для списка папок, не затрагивая виртуальные источники.
    private var emptyFoldersRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .foregroundColor(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Нет добавленных папок")
                    .foregroundColor(.primary)
                Text("Добавьте папку с музыкой, чтобы видеть локальные файлы.")
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
                Text("Добавить папку")
            }
            .padding(.vertical, 4)
        }
    }
}
