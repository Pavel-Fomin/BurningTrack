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
    let onShareTrack: () -> Void /// Отправка аудиофайла трека
    let onCopyTrack: () -> Void  /// Копирование iTunes-трека
    let onAddToPlayer: () -> Void /// Добавление iTunes-трека в плеер
    let onRenameTrack: (FileRenameStrategy) -> Void /// Переименование файла трека
    let onEditTags: () -> Void    /// Редактирование тегов трека
    let onArtworkTap: () -> Void /// Открытие карточки трека из меню
    let onShowInLibrary: () -> Void /// Переход к треку в фонотеке
    let onMoveToFolder: () -> Void  /// Перемещение файла трека в папку
    let onGoToArtist: () -> Void /// Переход к артисту трека
    let onGoToAlbum: () -> Void /// Переход к альбому трека

    /// Проверяет доступность пункта меню для строки треклиста.
    private func isMenuActionAvailable(
        _ action: TrackMenuAction
    ) -> Bool {
        TrackMenuActionAvailability.isAvailable(
            action,
            source: state.source,
            context: .trackList
        )
    }
    
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
            artworkRequest: state.artworkRequest,
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
        if isMenuActionAvailable(.details) {
            Button {
                onArtworkTap()
            } label: {
                Label("Track Info", systemImage: "info.circle")
            }
        }

        if isMenuActionAvailable(.share) {
            Button {
                onShareTrack()
            } label: {
                Label(
                    TrackSharePresentationText.actionTitle,
                    systemImage: "square.and.arrow.up"
                )
            }
        }

        if isMenuActionAvailable(.copy) {
            Button {
                onCopyTrack()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }

        if isMenuActionAvailable(.addToPlayer) {
            Button {
                onAddToPlayer()
            } label: {
                Label("Add to Player", systemImage: "waveform")
            }
        }

        if isMenuActionAvailable(.showInLibrary) {
            Button {
                onShowInLibrary()
            } label: {
                Label("Show in Library", systemImage: "magnifyingglass")
            }
        }

        if isMenuActionAvailable(.moveToFolder) {
            Button {
                onMoveToFolder()
            } label: {
                Label("Move", systemImage: "arrow.forward.folder")
            }
        }

        if isMenuActionAvailable(.goToArtist),
           state.collectionNavigationTarget?.artist != nil {
            Button {
                onGoToArtist()
            } label: {
                Label(
                    TrackListPresentationText.goToArtist,
                    systemImage: LibraryCollectionCategory.artists.systemImage
                )
            }
        }

        if isMenuActionAvailable(.goToAlbum),
           state.collectionNavigationTarget?.album != nil {
            Button {
                onGoToAlbum()
            } label: {
                Label(
                    TrackListPresentationText.goToAlbum,
                    systemImage: LibraryCollectionCategory.albums.systemImage
                )
            }
        }

        if isMenuActionAvailable(.editTags) ||
            isMenuActionAvailable(.renameFile) {
            Menu {
                if isMenuActionAvailable(.editTags) {
                    Button {
                        onEditTags()
                    } label: {
                        Label("Tags", systemImage: "tag")
                    }
                }

                if isMenuActionAvailable(.renameFile) {
                    // Системная секция делает "Название файла" подписью, а не пунктом меню.
                    Section("File Name") {
                        Button {
                            onRenameTrack(.artistTitle)
                        } label: {
                            Text(
                                FileRenamePresentationText.strategyTitle(
                                    for: FileRenameStrategy.artistTitle
                                )
                            )
                        }

                        Button {
                            onRenameTrack(.titleArtist)
                        } label: {
                            Text(
                                FileRenamePresentationText.strategyTitle(
                                    for: FileRenameStrategy.titleArtist
                                )
                            )
                        }

                        Button {
                            onRenameTrack(.manual)
                        } label: {
                            Text(
                                FileRenamePresentationText.strategyTitle(
                                    for: FileRenameStrategy.manual
                                )
                            )
                        }
                    }
                }
            } label: {
                Label("Edit", systemImage: "square.and.pencil")
            }
        }

        if isMenuActionAvailable(.deleteFromTrackList) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove from Tracklist", systemImage: "trash")
            }
        }
    }
}
