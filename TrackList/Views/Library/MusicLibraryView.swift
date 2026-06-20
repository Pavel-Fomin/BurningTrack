//
//  MusicLibraryView.swift
//  TrackList
//
//  Корневой экран фонотеки:
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
                emptyView

            // MARK: - Папки есть → показываем список
            } else {
                foldersList
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

    // MARK: - Пустое состояние

    private var emptyView: some View {
        VStack {
            Spacer()
            Button("Выбрать папку") {
                onAction(.addFolderTapped)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Список папок

    private var foldersList: some View {
        List {
            ForEach(state.folders) { folder in
                folderRow(folder)
            }

            // Добавить папку
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

    /// Строит строку прикреплённой папки без прямого доступа к менеджерам.
    private func folderRow(
        _ folder: LibraryMasterFolderRowState
    ) -> some View {
        Button {
            if folder.isAttaching { return }
            onAction(.openFolder(folder.id))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text(folder.name)
                    .lineLimit(1)

                Spacer()

                if folder.isAttaching {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(folder.isAttaching)
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
}
