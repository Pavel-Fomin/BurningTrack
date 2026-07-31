//
//  LibraryTrackActionMenuContent.swift
//  TrackList
//
//  Меню действий строки фонотеки.
//  Created by Pavel Fomin on 07.07.2026.
//

import SwiftUI

/// Единый состав ellipsis-меню для одиночного трека фонотеки.
struct LibraryTrackActionMenuContent: View {
    let labels: TrackActionMenuLabels
    /// Подготовленное presentation-состояние «Избранного» без чтения сервиса из View.
    let isFavorite: Bool
    let onDetails: () -> Void
    let onShare: () -> Void
    let onMoveToFolder: () -> Void
    let onAddToPlayer: () -> Void
    let onAddToTrackList: () -> Void
    let onToggleFavorite: () -> Void
    let collectionNavigationTarget: TrackCollectionNavigationTarget?
    /// Текущая категория выбранного значения коллекции, если меню открыто внутри него.
    let currentCollectionCategory: LibraryCollectionCategory?
    let onGoToArtist: () -> Void
    let onGoToAlbum: () -> Void
    let onEditTags: () -> Void
    let onRenameFile: (FileRenameStrategy) -> Void

    var body: some View {
        if isMenuActionAvailable(.details) {
            Button {
                onDetails()
            } label: {
                Label(labels.trackInfo, systemImage: "info.circle")
            }
        }

        if isMenuActionAvailable(.toggleFavorite) {
            TrackFavoriteMenuContent(
                isFavorite: isFavorite,
                onToggle: onToggleFavorite
            )
        }

        if isMenuActionAvailable(.share) {
            Button {
                onShare()
            } label: {
                Label(labels.share, systemImage: "square.and.arrow.up")
            }
        }

        if isMenuActionAvailable(.moveToFolder) {
            Button {
                onMoveToFolder()
            } label: {
                Label(labels.move, systemImage: "arrow.forward.folder")
            }
        }

        TrackAddDestinationMenuContent(
            canAddToPlayer: isMenuActionAvailable(.addToPlayer),
            canAddToTrackList: isMenuActionAvailable(.addToTrackList),
            addToTitle: labels.addTo,
            addToPlayerTitle: labels.addToPlayer,
            addToTrackListTitle: labels.addToTracklist,
            onAddToPlayer: onAddToPlayer,
            onAddToTrackList: onAddToTrackList
        )

        TrackGoToDestinationMenuContent(
            canGoToArtist: isMenuActionAvailable(.goToArtist) &&
                collectionNavigationTarget?.artist != nil,
            canGoToAlbum: isMenuActionAvailable(.goToAlbum) &&
                collectionNavigationTarget?.album != nil,
            goToTitle: labels.goTo,
            goToArtistTitle: labels.goToArtist,
            goToAlbumTitle: labels.goToAlbum,
            onGoToArtist: onGoToArtist,
            onGoToAlbum: onGoToAlbum
        )

        if isMenuActionAvailable(.editTags) ||
            isMenuActionAvailable(.renameFile) {
            Menu {
                if isMenuActionAvailable(.editTags) {
                    Button {
                        onEditTags()
                    } label: {
                        Label(labels.tags, systemImage: "tag")
                    }
                }

                if isMenuActionAvailable(.renameFile) {
                    // Системная секция делает "Название файла" подписью, а не пунктом меню.
                    Section(labels.fileName) {
                        Button {
                            onRenameFile(.artistTitle)
                        } label: {
                            Text(
                                FileRenamePresentationText.strategyTitle(
                                    for: FileRenameStrategy.artistTitle
                                )
                            )
                        }

                        Button {
                            onRenameFile(.titleArtist)
                        } label: {
                            Text(
                                FileRenamePresentationText.strategyTitle(
                                    for: FileRenameStrategy.titleArtist
                                )
                            )
                        }

                        Button {
                            onRenameFile(.manual)
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
                Label(labels.edit, systemImage: "square.and.pencil")
            }
        }
    }

    /// Доступность пунктов берётся из каноничных правил фонотеки.
    private func isMenuActionAvailable(_ action: TrackMenuAction) -> Bool {
        TrackMenuActionAvailability.isAvailable(
            action,
            source: .library,
            context: .library,
            currentCollectionCategory: currentCollectionCategory
        )
    }
}

/// Подписи контекстного меню передаются вызывающим presentation-слоем.
struct TrackActionMenuLabels {
    let trackInfo: String
    let share: String
    let move: String
    let addTo: String
    let addToPlayer: String
    let addToTracklist: String
    let goTo: String
    let goToArtist: String
    let goToAlbum: String
    let tags: String
    let fileName: String
    let edit: String

}

/// Визуальное состояние единственного переключателя «Избранное» в контекстном меню.
enum TrackFavoriteMenuPresentation: Equatable {
    /// Трек отсутствует в системном треклисте «Избранное».
    case notFavorite
    /// Трек находится в системном треклисте «Избранное».
    case favorite

    /// Формирует состояние из готового значения presenter-слоя.
    init(isFavorite: Bool) {
        self = isFavorite ? .favorite : .notFavorite
    }

    /// Сохраняет те же SF Symbol, что используются в кнопке мини-плеера.
    var systemImage: String {
        switch self {
        case .notFavorite:
            return "heart"
        case .favorite:
            return "heart.fill"
        }
    }
}

/// Отображает самостоятельное действие «Избранное», не меняя состояние локально во View.
struct TrackFavoriteMenuContent: View {
    let isFavorite: Bool
    let onToggle: () -> Void

    /// Состояние иконки подготовлено до передачи в SwiftUI-компонент.
    private var presentation: TrackFavoriteMenuPresentation {
        TrackFavoriteMenuPresentation(isFavorite: isFavorite)
    }

    var body: some View {
        Button(action: onToggle) {
            Label(
                String(localized: "Favorite"),
                systemImage: presentation.systemImage
            )
        }
    }
}

/// Визуальные варианты блока добавления трека в доступные назначения.
enum TrackAddDestinationMenuPresentation: Equatable {
    /// Ни одно действие добавления недоступно.
    case none
    /// Доступно только добавление в плеер.
    case addToPlayer
    /// Доступно только добавление в треклист.
    case addToTrackList
    /// Оба действия доступны и отображаются во вложенном меню.
    case grouped

    /// Выбирает структуру меню, не меняя правила доступности действий.
    init(canAddToPlayer: Bool, canAddToTrackList: Bool) {
        switch (canAddToPlayer, canAddToTrackList) {
        case (true, true):
            self = .grouped
        case (true, false):
            self = .addToPlayer
        case (false, true):
            self = .addToTrackList
        case (false, false):
            self = .none
        }
    }
}

/// Формирует общий блок действий добавления, сохраняя самостоятельный пункт при одном назначении.
struct TrackAddDestinationMenuContent: View {
    let canAddToPlayer: Bool
    let canAddToTrackList: Bool
    let addToTitle: String
    let addToPlayerTitle: String
    let addToTrackListTitle: String
    let onAddToPlayer: () -> Void
    let onAddToTrackList: () -> Void

    /// Правило отображения отделено от SwiftUI, чтобы его можно было проверить модульно.
    private var presentation: TrackAddDestinationMenuPresentation {
        TrackAddDestinationMenuPresentation(
            canAddToPlayer: canAddToPlayer,
            canAddToTrackList: canAddToTrackList
        )
    }

    var body: some View {
        switch presentation {
        case .none:
            EmptyView()

        case .addToPlayer:
            addToPlayerButton

        case .addToTrackList:
            addToTrackListButton

        case .grouped:
            Menu {
                addToPlayerButton
                addToTrackListButton
            } label: {
                Label(addToTitle, systemImage: "plus")
            }
        }
    }

    /// Сохраняет подпись и иконку существующего действия добавления в плеер.
    private var addToPlayerButton: some View {
        Button {
            onAddToPlayer()
        } label: {
            Label(addToPlayerTitle, systemImage: "waveform")
        }
    }

    /// Сохраняет подпись и иконку существующего действия добавления в треклист.
    private var addToTrackListButton: some View {
        Button {
            onAddToTrackList()
        } label: {
            Label(addToTrackListTitle, systemImage: "list.star")
        }
    }
}

/// Визуальные варианты блока перехода к доступным значениям коллекции.
enum TrackGoToDestinationMenuPresentation: Equatable {
    /// Ни один переход недоступен.
    case none
    /// Доступен только переход к артисту.
    case goToArtist
    /// Доступен только переход к альбому.
    case goToAlbum
    /// Оба перехода доступны и отображаются во вложенном меню.
    case grouped

    /// Выбирает структуру меню, не меняя правила доступности навигации.
    init(canGoToArtist: Bool, canGoToAlbum: Bool) {
        switch (canGoToArtist, canGoToAlbum) {
        case (true, true):
            self = .grouped
        case (true, false):
            self = .goToArtist
        case (false, true):
            self = .goToAlbum
        case (false, false):
            self = .none
        }
    }
}

/// Формирует общий блок переходов, сохраняя самостоятельный пункт при одной доступной цели.
struct TrackGoToDestinationMenuContent: View {
    let canGoToArtist: Bool
    let canGoToAlbum: Bool
    let goToTitle: String
    let goToArtistTitle: String
    let goToAlbumTitle: String
    let onGoToArtist: () -> Void
    let onGoToAlbum: () -> Void

    /// Правило отображения отделено от SwiftUI, чтобы его можно было проверить модульно.
    private var presentation: TrackGoToDestinationMenuPresentation {
        TrackGoToDestinationMenuPresentation(
            canGoToArtist: canGoToArtist,
            canGoToAlbum: canGoToAlbum
        )
    }

    var body: some View {
        switch presentation {
        case .none:
            EmptyView()

        case .goToArtist:
            goToArtistButton

        case .goToAlbum:
            goToAlbumButton

        case .grouped:
            Menu {
                goToArtistButton
                goToAlbumButton
            } label: {
                Label(goToTitle, systemImage: "arrowshape.turn.up.right")
            }
        }
    }

    /// Сохраняет подпись и иконку существующего действия перехода к артисту.
    private var goToArtistButton: some View {
        Button {
            onGoToArtist()
        } label: {
            Label(
                goToArtistTitle,
                systemImage: LibraryCollectionCategory.artists.systemImage
            )
        }
    }

    /// Сохраняет подпись и иконку существующего действия перехода к альбому.
    private var goToAlbumButton: some View {
        Button {
            onGoToAlbum()
        } label: {
            Label(
                goToAlbumTitle,
                systemImage: LibraryCollectionCategory.albums.systemImage
            )
        }
    }
}
