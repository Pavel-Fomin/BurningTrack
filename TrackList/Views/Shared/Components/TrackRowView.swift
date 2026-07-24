//
//  TrackRowView.swift
//  TrackList
//
//  Компонент UI для отображения трека в списке
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI
import UIKit

enum TrackRowSelectionPlacement {
    case leading
    case trailing
}

struct TrackRowView<ActionMenuContent: View>: View {

    // MARK: - Входные параметры

    let track: any TrackDisplayable
    let isCurrent: Bool
    let isPlaying: Bool
    let isHighlighted: Bool
    let artworkRequest: ArtworkRequest?
    let title: String?
    let artist: String?
    let duration: Double?
    let onRowTap: () -> Void          /// Тап по правой части строки (воспроизведение / пауза)
    let showsSelection: Bool          /// Показывать radio или нет
    let isSelected: Bool              /// Radio (пустой / выбранный)
    let onToggleSelection: (() -> Void)?
    let selectionPlacement: TrackRowSelectionPlacement
    let showsFileFormat: Bool         /// Показывать формат файла в правой колонке
    let isContentAvailable: Bool      /// Доступно ли локальное содержимое файла для действий строки
    
    var trackListNames: [String]? = nil
    var useNativeSwipeActions: Bool = false
    /// Внешнее содержимое меню действий строки.
    private let actionMenuContent: (() -> ActionMenuContent)?
    /// Внешнее содержимое правой части строки, которое при наличии заменяет меню действий.
    private let trailingContent: AnyView?

    
    init(
        track: any TrackDisplayable,
        isCurrent: Bool,
        isPlaying: Bool,
        isHighlighted: Bool,
        artworkRequest: ArtworkRequest?,
        title: String?,
        artist: String?,
        duration: Double?,
        onRowTap: @escaping () -> Void,
        showsSelection: Bool = false,
        isSelected: Bool = false,
        onToggleSelection: (() -> Void)? = nil,
        selectionPlacement: TrackRowSelectionPlacement = .leading,
        showsFileFormat: Bool = true,
        isContentAvailable: Bool? = nil,
        trackListNames: [String]? = nil,
        useNativeSwipeActions: Bool = false,
        trailingContent: AnyView? = nil,
        @ViewBuilder actionMenuContent: @escaping () -> ActionMenuContent
    ) {
        self.init(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: isHighlighted,
            artworkRequest: artworkRequest,
            title: title,
            artist: artist,
            duration: duration,
            onRowTap: onRowTap,
            showsSelection: showsSelection,
            isSelected: isSelected,
            onToggleSelection: onToggleSelection,
            selectionPlacement: selectionPlacement,
            showsFileFormat: showsFileFormat,
            isContentAvailable: isContentAvailable,
            trackListNames: trackListNames,
            useNativeSwipeActions: useNativeSwipeActions,
            trailingContent: trailingContent,
            storedActionMenuContent: actionMenuContent
        )
    }

    fileprivate init(
        track: any TrackDisplayable,
        isCurrent: Bool,
        isPlaying: Bool,
        isHighlighted: Bool,
        artworkRequest: ArtworkRequest?,
        title: String?,
        artist: String?,
        duration: Double?,
        onRowTap: @escaping () -> Void,
        showsSelection: Bool = false,
        isSelected: Bool = false,
        onToggleSelection: (() -> Void)? = nil,
        selectionPlacement: TrackRowSelectionPlacement = .leading,
        showsFileFormat: Bool = true,
        isContentAvailable: Bool? = nil,
        trackListNames: [String]? = nil,
        useNativeSwipeActions: Bool = false,
        trailingContent: AnyView? = nil,
        storedActionMenuContent: (() -> ActionMenuContent)?
    ) {
        self.track = track
        self.isCurrent = isCurrent
        self.isPlaying = isPlaying
        self.isHighlighted = isHighlighted
        self.artworkRequest = artworkRequest
        self.title = title
        self.artist = artist
        self.duration = duration
        self.onRowTap = onRowTap
        self.showsSelection = showsSelection
        self.isSelected = isSelected
        self.onToggleSelection = onToggleSelection
        self.selectionPlacement = selectionPlacement
        self.showsFileFormat = showsFileFormat
        self.isContentAvailable = isContentAvailable ?? track.isAvailable
        self.trackListNames = trackListNames
        self.useNativeSwipeActions = useNativeSwipeActions
        self.trailingContent = trailingContent
        self.actionMenuContent = storedActionMenuContent
    }
    // MARK: - UI

    /// Есть ли отображаемый исполнитель
    private var hasArtist: Bool {
        guard let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return false }
        return artist.isEmpty == false
    }

    /// Возвращает локализованную замену, если в модели отсутствуют данные для заголовка.
    private var displayTitle: String {
        let value = (title ?? track.fileName)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? AppMessagePresentationText.unavailableValue : value
    }

    /// Формат файла для правой колонки метаданных
    private var fileFormatLabel: String? {
        let extensionValue = (track.fileName as NSString).pathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !extensionValue.isEmpty else { return nil }
        return extensionValue
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // Radio (только в режиме выбора)
            if showsSelection && selectionPlacement == .leading {
                selectionButton
                    // Центруем область выбора относительно обложки, а не дополнительной строки «уже в».
                    .padding(.top, 2)
            }

            rowTapContent

            // Экран может нейтрально заменить меню совместимым содержимым правой части строки.
            trailingArea
                // Центруем меню относительно обложки, а не дополнительной строки «уже в».
                .padding(.top, 2)

            if showsSelection && selectionPlacement == .trailing {
                selectionButton
                    // Центруем область выбора относительно обложки, а не дополнительной строки «уже в».
                    .padding(.top, 2)
            }
        }
        // высота общей строки
        .padding(.vertical, -6)
        .padding(.horizontal, 4)
        .opacity(isContentAvailable ? 1 : 0.4)
        .listRowBackground(rowHighlightColor)
    }

    /// Единая область тапа для обложки и текстовой части строки.
    private var rowTapContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                artworkView

                trackInfoView
            }

            trackListMembershipView
                // Дополнительная строка начинается под текстом, не сдвигая основной блок.
                .padding(.leading, 60)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            handleRowTap()
        }
    }

    /// Выполняет единое действие строки для основной области строки.
    private func handleRowTap() {
        guard isContentAvailable else {
            ToastManager.shared.handle(
                .trackUnavailable(title: track.title ?? track.fileName)
            )
            return
        }

        onRowTap()
    }

    private var selectionButton: some View {
        Button {
            onToggleSelection?()
        } label: {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(
                    isCurrent
                        ? .secondary
                        : (isSelected ? .green : .secondary)
                )
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)         // ← фикс: одинаково для всех строк
        .contentShape(Rectangle())
    }

    /// Меню действий, состав которого передаётся внешним экраном
    @ViewBuilder
    private var trackActionsMenu: some View {
        if let actionMenuContent {
            Menu {
                actionMenuContent()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// Выбирает внешнее содержимое правой области или сохраняет существующее меню действий.
    @ViewBuilder
    private var trailingArea: some View {
        if let trailingContent {
            trailingContent
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        } else {
            trackActionsMenu
        }
    }

    // MARK: - Обложка

    /// Статичная круглая обложка трека с индикатором текущего воспроизведения.
    private var artworkView: some View {
        ZStack {
            ArtworkPreparationView(request: artworkRequest) { image in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
            }

            if isCurrent {
                ActiveArtworkOverlayView(isPlaying: isPlaying)
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
    }

    // MARK: - Информация о треке

    private var trackInfoView: some View {
        HStack(alignment: .center, spacing: 8) {
            leftTextColumn
                .frame(maxWidth: .infinity, alignment: .leading)

            metadataColumn
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Левая колонка с основным текстом трека
    private var leftTextColumn: some View {
        VStack(alignment: .leading, spacing: hasArtist ? 2 : 0) {
            if hasArtist, let artistText = artist {
                Text(artistText)
                    // Верхняя строка сохраняет прежний основной стиль.
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Text(displayTitle)
                // Название использует тот же шрифт, что и исполнитель.
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    /// Дополнительная строка с треклистами, в которых уже есть трек.
    @ViewBuilder
    private var trackListMembershipView: some View {
        if let trackListNames, !trackListNames.isEmpty {
            Text(
                SharedPresentationText.tracklistMembership(
                    trackListNames.joined(separator: ", ")
                )
            )
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(4)
        }
    }

    /// Правая колонка с техническими метаданными трека
    private var metadataColumn: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if showsFileFormat, let fileFormatLabel {
                Text(fileFormatLabel)
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.65))
                    .lineLimit(1)
            }

            Text(SharedPresentationText.duration(duration ?? track.duration))
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .multilineTextAlignment(.trailing)
        .layoutPriority(1)
    }

    // MARK: - Подсветка строки

    private var rowHighlightColor: Color {
        if isHighlighted {
            return Color.gray.opacity(0.12)          // Подсветка при открытом шите
        } else if isCurrent {
            return Color.accentColor.opacity(0.12)   // Подсветка текущего трека
        } else {
            return Color.clear
        }
    }
}

extension TrackRowView where ActionMenuContent == EmptyView {
    /// Создаёт строку без меню действий.
    init(
        track: any TrackDisplayable,
        isCurrent: Bool,
        isPlaying: Bool,
        isHighlighted: Bool,
        artworkRequest: ArtworkRequest?,
        title: String?,
        artist: String?,
        duration: Double?,
        onRowTap: @escaping () -> Void,
        showsSelection: Bool = false,
        isSelected: Bool = false,
        onToggleSelection: (() -> Void)? = nil,
        selectionPlacement: TrackRowSelectionPlacement = .leading,
        showsFileFormat: Bool = true,
        isContentAvailable: Bool? = nil,
        trackListNames: [String]? = nil,
        useNativeSwipeActions: Bool = false
    ) {
        self.init(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: isHighlighted,
            artworkRequest: artworkRequest,
            title: title,
            artist: artist,
            duration: duration,
            onRowTap: onRowTap,
            showsSelection: showsSelection,
            isSelected: isSelected,
            onToggleSelection: onToggleSelection,
            selectionPlacement: selectionPlacement,
            showsFileFormat: showsFileFormat,
            isContentAvailable: isContentAvailable,
            trackListNames: trackListNames,
            useNativeSwipeActions: useNativeSwipeActions,
            trailingContent: nil,
            storedActionMenuContent: nil
        )
    }
}
