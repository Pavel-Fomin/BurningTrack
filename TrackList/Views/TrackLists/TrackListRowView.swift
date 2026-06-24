//
//  TrackListRowView.swift
//  TrackList
//
//  Строка трека в треклисте.
//   UI-КОМПОНЕНТ:
// - не содержит свайпов
// - не знает про SheetManager
// - не содержит навигации
// - все действия передаются через колбэки
//
//  Created by Pavel Fomin on 03.08.2025.
//

import SwiftUI

struct TrackListRowView: View {
    
    // MARK: - Input
    
    let state: TrackListRowState /// Готовое состояние строки треклиста
    let onTap: () -> Void        /// Тап по строке (воспроизведение / пауза)
    let onDelete: () -> Void     /// Удаление строки (локальное действие)
    let onRenameTrack: (FileRenameStrategy) -> Void /// Переименование файла трека
    let onEditTags: () -> Void    /// Редактирование тегов трека
    let onArtworkTap: () -> Void /// Открытие карточки трека из меню
    let onShowInLibrary: () -> Void /// Переход к треку в фонотеке
    let onMoveToFolder: () -> Void  /// Перемещение файла трека в папку
    
    // MARK: - UI
    
    var body: some View {
        TrackRowView(
            track: Track(
                listItemId: state.id,
                trackId: state.trackId,
                title: state.title,
                artist: state.artist,
                duration: state.duration,
                fileName: state.fileName,
                isAvailable: state.isAvailable
            ),
            isCurrent: state.isCurrent,
            isPlaying: state.isPlaying,
            isHighlighted: state.isHighlighted, /// Подсветка управляется wrapper'ом
            artwork: state.artwork,
            title: state.title,
            artist: state.artist,
            duration: state.duration,
            onRowTap: onTap,                    /// Правая зона — воспроизведение / пауза
            showsFileFormat: state.showsFileFormat
        ) {
            trackListActionMenuContent
        }
        
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }

    /// Меню действий строки треклиста.
    @ViewBuilder
    private var trackListActionMenuContent: some View {
        Button {
            onArtworkTap()
        } label: {
            Label("О треке", systemImage: "info.circle")
        }

        Button {
            onShowInLibrary()
        } label: {
            Label("Показать в папке", systemImage: "scope")
        }

        Button {
            onMoveToFolder()
        } label: {
            Label("Переместить", systemImage: "arrow.forward.folder")
        }

        Menu {
            Button {
                onEditTags()
            } label: {
                Label("Теги", systemImage: "tag")
            }

            // Системная секция делает "Название файла" подписью, а не пунктом меню.
            Section("Название файла") {
                Button {
                    onRenameTrack(.artistTitle)
                } label: {
                    Text("Артист - Название")
                }

                Button {
                    onRenameTrack(.titleArtist)
                } label: {
                    Text("Название - Артист")
                }

                Button {
                    onRenameTrack(.manual)
                } label: {
                    Text("Вручную")
                }
            }
        } label: {
            Label("Редактировать", systemImage: "square.and.pencil")
        }

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Удалить из треклиста", systemImage: "trash")
        }
    }
}
