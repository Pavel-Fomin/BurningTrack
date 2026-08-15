//
//  LibraryTracksView.swift
//  TrackList
//
//  Отображает список треков из папки, сгруппированных по дате.
//
//  Created by Pavel Fomin on 09.08.2025.
//


import SwiftUI
import UIKit

struct LibraryTracksView: View {

    let folder: LibraryFolder
    /// Семантическая статистика для формирования вторичной строки заголовка во View.
    let summary: TrackCollectionSummary?
    /// Подпапки текущей папки, которые нужно показать над секциями треков.
    let subfolders: [LibraryFolder]
    /// Передаёт навигационное действие владельцу flow фонотеки.
    let onSubfolderTap: (LibraryFolder) -> Void
    /// Передаёт видимые треки для экспорта владельцу flow папки.
    let onExportTracks: ([LibraryTrack]) -> Void
    let revealRequest: LibraryRevealRequest?
    let onRevealHandled: (UUID) -> Void
    /// Published-состояние «Избранного» для presentation state строк.
    let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?
    @Binding var selectionActionSender: (any LibraryTracksActionSending)?
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var sheetManager: SheetManager
    /// Container удерживает graph, а View наблюдает Published screen state без сохранённого snapshot.
    @ObservedObject private var tracksViewModel: LibraryTracksViewModel
    /// Контроллер iCloud принадлежит времени жизни destination, а не пересчёту родительского View.
    @State private var cloudAvailabilityController: LibraryCloudAvailabilityScreenController
    /// Стабильный handler передаётся Container вместе с graph destination и не создаётся во View.
    private let cloudAvailabilityActionHandler: LibraryCloudAvailabilityActionHandler
    @ObservedObject var settingsManager: AppSettingsManager
    /// Playback-состояние сохраняется на всё время жизни открытой папки.
    @StateObject private var playbackStateController: LibraryTrackPlaybackStateController
    /// Локальный снимок сохраняет реактивность строк без наблюдения PlayerViewModel.
    @State private var favoriteTrackIds: Set<UUID>
    /// Координатор reveal не должен терять отложенный scroll при пересчёте родительского экрана.
    @StateObject private var revealCoordinator: LibraryTrackRevealCoordinator
    /// Обработчики строк фиксируются вместе с графом screen-local зависимостей.
    @State private var presentationHandler: LibraryTrackPresentationHandler
    @State private var commandHandler: LibraryTrackCommandHandler
    private let selectionActionBarCoordinator = LibrarySelectionActionBarCoordinator()

    // MARK: -  Локальное состояние для скролла
    
    @State private var scrollRequest: LibraryScrollRequest?

    /// Показывает, активен ли локальный режим выбора фонотеки.
    private var isSelecting: Bool {
        tracksViewModel.state.isSelecting
    }

    /// Все видимые треки текущих секций для передачи в строки списком контекста.
    private var allVisibleTracks: [LibraryTrack] {
        tracksViewModel.state.sections.flatMap(\.tracks)
    }

    /// Вычисление относится к представлению toolbar и использует готовый screen state без мутации selection.
    private var areAllVisibleTracksSelected: Bool {
        let visibleIDs = Set(allVisibleTracks.map(\.id))
        return visibleIDs.isEmpty == false
            && visibleIDs.isSubset(of: Set(tracksViewModel.state.selectedTrackIDs.ids))
    }

    // MARK: - Инициализация

    init(
        folder: LibraryFolder,
        summary: TrackCollectionSummary? = nil,
        subfolders: [LibraryFolder] = [],
        onSubfolderTap: @escaping (LibraryFolder) -> Void = { _ in },
        onExportTracks: @escaping ([LibraryTrack]) -> Void = { _ in },
        revealRequest: LibraryRevealRequest? = nil,
        onRevealHandled: @escaping (UUID) -> Void = { _ in },
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding,
        tracksViewModel: LibraryTracksViewModel,
        cloudAvailabilityController: LibraryCloudAvailabilityScreenController,
        cloudAvailabilityActionHandler: LibraryCloudAvailabilityActionHandler,
        settingsManager: AppSettingsManager,
        playbackStateController: LibraryTrackPlaybackStateController,
        revealCoordinator: LibraryTrackRevealCoordinator,
        presentationHandler: LibraryTrackPresentationHandler,
        commandHandler: LibraryTrackCommandHandler,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?> = .constant(nil),
        selectionActionSender: Binding<(any LibraryTracksActionSending)?> = .constant(nil)
    ) {
        self.folder = folder
        self.summary = summary
        self.subfolders = subfolders
        self.onSubfolderTap = onSubfolderTap
        self.onExportTracks = onExportTracks
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
        self.tracksViewModel = tracksViewModel
        self._cloudAvailabilityController = State(initialValue: cloudAvailabilityController)
        self.cloudAvailabilityActionHandler = cloudAvailabilityActionHandler
        self.settingsManager = settingsManager
        self._playbackStateController = StateObject(wrappedValue: playbackStateController)
        self._revealCoordinator = StateObject(wrappedValue: revealCoordinator)
        self._presentationHandler = State(initialValue: presentationHandler)
        self._commandHandler = State(initialValue: commandHandler)
        self._selectionActionBarConfig = selectionActionBarConfig
        self._selectionActionSender = selectionActionSender
        self._favoriteTrackIds = State(
            initialValue: favoriteTrackIdsProvider.favoriteTrackIds
        )
    }

    // MARK: - Интерфейс

    var body: some View {
        contentView
            // Навигационный toolbar подключается снаружи списка, чтобы не влиять на строки.
            .navigationTitle(folder.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isSelecting)
            .toolbar {
                if isSelecting == false {
                    ToolbarItem(placement: .principal) {
                        ScreenToolbarTitleView(
                            title: folder.name,
                            subtitle: summary.map(SharedPresentationText.trackCollectionSummary)
                        )
                    }
                }

                navigationToolbarContent
            }
            .refreshable {
                tracksViewModel.send(.refreshRequested)
            }
            .task {
                selectionActionSender = tracksViewModel
                tracksViewModel.send(.screenAppeared)
                handleRevealDecision(
                    revealCoordinator.evaluateReveal(
                        trackSections: tracksViewModel.state.sections,
                        didLoad: tracksViewModel.state.didLoad,
                        isLoading: tracksViewModel.state.isLoading
                    )
                )
            }
            .onChange(of: revealRequest?.requestId) { _, _ in
                tracksViewModel.send(.revealRequestReceived(revealRequest))
                handleRevealDecision(
                    revealCoordinator.receiveRevealRequest(
                        revealRequest,
                        trackSections: tracksViewModel.state.sections,
                        didLoad: tracksViewModel.state.didLoad,
                        isLoading: tracksViewModel.state.isLoading
                    )
                )
            }
            .onChange(of: tracksViewModel.state.selectionActionBarState) { _, newValue in
                updateSelectionActionBarConfig(from: newValue)
            }
            .onReceive(favoriteTrackIdsProvider.favoriteTrackIdsPublisher) { favoriteTrackIds in
                self.favoriteTrackIds = favoriteTrackIds
            }
            .onDisappear {
                cloudAvailabilityActionHandler.handle(.screenDidDisappear)
            }
    }

    // Контент панели навигации отдаёт наружу только пользовательские намерения.
    @ToolbarContentBuilder
    private var navigationToolbarContent: some ToolbarContent {
        if isSelecting {
            LibraryBulkSelectionToolbar(
                areAllVisibleTracksSelected: areAllVisibleTracksSelected,
                onToggleSelectAll: handleToggleSelectAll,
                onBatchActionSelection: handleBatchActionSelection,
                onCancel: handleTapCancel
            )

        } else {

            /// Меню обычного режима.
            ToolbarItem(placement: .topBarTrailing) {
                LibraryTracksToolbarMenuButton(
                    selectedSortMode: tracksViewModel.state.sortMode,
                    availableSortModes: LibraryTrackSortMode.allCases,
                    onSelect: handleTapSelect,
                    onSortModeSelection: handleSortModeSelection,
                    onBatchActionSelection: handleBatchActionSelection,
                    onExport: handleTapExport,
                    isExportEnabled: allVisibleTracks.isEmpty == false
                )
            }
        }
    }

    /// Основной контент экрана: список и слой загрузки.
    private var contentView: some View {
        ZStack {
            tracksListView

            loadingOverlayView
        }
    }

    /// Список треков с обработчиками прокрутки и lifecycle списка.
    private var tracksListView: some View {
        ScrollViewReader { proxy in
            List {
                folderSectionView()

                LibraryTrackSectionsListView(
                    sections: tracksViewModel.state.sections,
                    allTracks: allVisibleTracks,
                    playbackSource: .libraryFolder(id: folder.id),
                    currentCollectionCategory: nil,
                    trackListMembershipsById: tracksViewModel.state.trackListMembershipsById,
                    presentationHandler: presentationHandler,
                    cloudAvailabilityStateStore: cloudAvailabilityController.stateStore(for:),
                    cloudAvailabilityActionHandler: cloudAvailabilityActionHandler,
                    favoriteTrackIds: favoriteTrackIds,
                    commandHandler: commandHandler,
                    playbackStateController: playbackStateController,
                    revealedTrackID: revealCoordinator.revealedTrackID,
                    highlightedTrackID: sheetManager.highlightedRowID,
                    shouldShowTags: settingsManager.settings.visible.metadata.isTagReadingEnabled,
                    shouldShowTrackListMembership: settingsManager.settings.visible.library.isTrackListMembershipVisible,
                    shouldShowFileFormat: settingsManager.settings.visible.library.isFileFormatVisible,
                    isSelecting: isSelecting,
                    selectedTrackIDs: tracksViewModel.state.selectedTrackIDs
                )
            }
            .listStyle(.plain)
            .globalBottomScrollReserve()
            .scrollContentBackground(.hidden)

            .onAppear {
                handleTracksListAppear()
            }
            // Как только появилась цель — скроллим.
            .onChange(of: scrollRequest) { _, request in
                handleScrollRequest(request, proxy: proxy)
            }
            .onChange(of: tracksViewModel.state.sections) { _, _ in
                handleRevealDecision(
                    revealCoordinator.evaluateReveal(
                        trackSections: tracksViewModel.state.sections,
                        didLoad: tracksViewModel.state.didLoad,
                        isLoading: tracksViewModel.state.isLoading
                    )
                )
            }
            .onChange(of: playbackStateController.currentDisplayableId) { _, _ in
                requestActiveTrackScrollIfNeeded()
            }
            .onChange(of: playbackStateController.currentContext) { _, _ in
                requestActiveTrackScrollIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                tracksViewModel.send(.scenePhaseChanged(newPhase))
                handleScenePhaseChange(newPhase)
            }
        }
    }

    // MARK: - Секция подпапок

    @ViewBuilder
    private func folderSectionView() -> some View {
        if subfolders.isEmpty == false {
            Section {
                ForEach(subfolders) { subfolder in
                    LibraryFolderRowView(
                        name: subfolder.name,
                        showsDisclosureIndicator: true
                    ) {
                        onSubfolderTap(subfolder)
                    }
                }
            }
        }
    }

    /// Скелетон / лоадер поверх пустого списка во время загрузки.
    @ViewBuilder
    private var loadingOverlayView: some View {
        if tracksViewModel.state.isLoading && tracksViewModel.state.sections.isEmpty {
            VStack {
                Spacer()
                ProgressView("Loading Tracks")
                    .progressViewStyle(.circular)
                    .font(.headline)
                    .padding()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground).opacity(0.9))
        }
    }

    // MARK: - Вспомогательное

    /// Синхронизирует состояние при появлении списка.
    private func handleTracksListAppear() {
        cloudAvailabilityActionHandler.handle(.screenDidAppear)
        requestActiveTrackScrollIfNeeded()
        restoreSelectionActionBarIfNeeded()
    }

    /// Обрабатывает нажатие выбора в toolbar.
    private func handleTapSelect() {
        // Вход в выбор без заранее выбранного batch-действия.
        tracksViewModel.send(.selectionStarted)
    }

    /// Передаёт треки в текущем отображаемом порядке обработчику папки.
    private func handleTapExport() {
        guard allVisibleTracks.isEmpty == false else { return }
        onExportTracks(allVisibleTracks)
    }

    /// Обрабатывает массовое переключение выбора в toolbar.
    private func handleToggleSelectAll() {
        // Массовое переключение выбора остаётся во ViewModel.
        tracksViewModel.send(.selectAllToggled)
    }

    /// Обрабатывает выбор режима сортировки из toolbar menu.
    private func handleSortModeSelection(_ mode: LibraryTrackSortMode) {
        tracksViewModel.send(.sortModeSelected(mode))
    }

    /// Обрабатывает отмену режима выбора.
    private func handleTapCancel() {
        // Отмена полностью сбрасывает режим и текущий выбор.
        resetMultiselect()
    }

    /// Выполняет программную прокрутку по отложенному запросу.
    private func handleScrollRequest(
        _ request: LibraryScrollRequest?,
        proxy: ScrollViewProxy
    ) {
        guard let request else { return }

        let targetId = request.targetId

        withAnimation(.easeInOut(duration: 0.35)) {
            proxy.scrollTo(targetId, anchor: .center)
        }

        if case .reveal(let revealRequest) = request,
           let handledRequestId = revealCoordinator.markRevealScrollPerformed(revealRequest) {
            onRevealHandled(handledRequestId)
        }

        scrollRequest = nil
    }

    /// Обрабатывает возврат приложения в активную фазу.
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard newPhase == .active else { return }
        requestActiveTrackScrollIfNeeded()
    }

    /// Синхронизирует конфигурацию нижней панели подтверждения для родительского host.
    private func updateSelectionActionBarConfig(
        from state: LibrarySelectionActionBarState?
    ) {
        guard let state else {
            selectionActionBarConfig = nil
            return
        }

        selectionActionBarConfig = selectionActionBarCoordinator.makeConfig(from: state)
    }

    /// Восстанавливает config только из уже активного selection, не записывая nil при remount списка.
    private func restoreSelectionActionBarIfNeeded() {
        guard let state = tracksViewModel.state.selectionActionBarState else {
            return
        }

        selectionActionBarConfig = selectionActionBarCoordinator.makeConfig(from: state)
    }

    /// Сбрасывает режим мультиселекта и очищает нижнюю панель.
    private func resetMultiselect() {
        tracksViewModel.send(.selectionCancelled)
    }

    /// Обрабатывает выбор batch-действия с учётом текущего режима и выбора.
    private func handleBatchActionSelection(_ action: BulkTrackAction) {
        tracksViewModel.send(.batchActionSelected(action))
    }

    /// Запрашивает прокрутку к активному треку, если она не конфликтует с reveal.
    private func requestActiveTrackScrollIfNeeded() {
        guard let request = revealCoordinator.activeTrackScrollRequestIfNeeded(
            currentDisplayableId: playbackStateController.currentDisplayableId,
            currentContext: playbackStateController.currentContext,
            trackSections: tracksViewModel.state.sections,
            hasPendingScrollRequest: scrollRequest != nil
        ) else {
            return
        }

        scrollRequest = request
    }

    /// Выполняет SwiftUI-эффекты по готовому решению reveal coordinator.
    private func handleRevealDecision(_ decision: LibraryTrackRevealDecision) {
        switch decision {
        case .none,
             .waitForTracks:
            return

        case .complete(let requestId):
            onRevealHandled(requestId)

        case .reveal(let revealRequest):
            Task { @MainActor in
                // Даём List один проход на создание строки перед scrollTo.
                await Task.yield()
                scrollRequest = .reveal(revealRequest)

                try? await Task.sleep(nanoseconds: 1_200_000_000)
                revealCoordinator.clearRevealHighlightIfCurrent(revealRequest)
            }
        }
    }
}

/// Нативная кнопка toolbar-меню с subtitle выбранной сортировки, как в треклистах и папках.
struct LibraryTracksToolbarMenuButton: UIViewRepresentable {
    /// Текущий режим сортировки треков в открытой папке.
    let selectedSortMode: LibraryTrackSortMode
    /// Режимы сортировки, доступные для текущего списка.
    let availableSortModes: [LibraryTrackSortMode]
    /// Запускает режим выбора.
    let onSelect: () -> Void
    /// Передаёт выбранный режим сортировки во View.
    let onSortModeSelection: (LibraryTrackSortMode) -> Void
    /// Передаёт выбранное batch-действие во View.
    let onBatchActionSelection: (BulkTrackAction) -> Void
    /// Запускает экспорт видимых треков, если он доступен для текущего экрана.
    let onExport: (() -> Void)?
    /// Определяет доступность пункта экспорта.
    let isExportEnabled: Bool
    /// Accessibility label для кнопки действий текущего списка.
    let accessibilityLabel: String

    // MARK: - Инициализация

    /// Создаёт меню действий списка с необязательным пунктом экспорта.
    init(
        selectedSortMode: LibraryTrackSortMode,
        availableSortModes: [LibraryTrackSortMode],
        onSelect: @escaping () -> Void,
        onSortModeSelection: @escaping (LibraryTrackSortMode) -> Void,
        onBatchActionSelection: @escaping (BulkTrackAction) -> Void,
        onExport: (() -> Void)? = nil,
        isExportEnabled: Bool = false,
        accessibilityLabel: String = String(localized: "Library Folder Actions")
    ) {
        self.selectedSortMode = selectedSortMode
        self.availableSortModes = availableSortModes
        self.onSelect = onSelect
        self.onSortModeSelection = onSortModeSelection
        self.onBatchActionSelection = onBatchActionSelection
        self.onExport = onExport
        self.isExportEnabled = isExportEnabled
        self.accessibilityLabel = accessibilityLabel
    }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = false
        button.accessibilityLabel = accessibilityLabel
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.menu = makeMenu()
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        button.menu = makeMenu()
    }

    /// Собирает системное меню, где subtitle и checkmark рисуются UIKit.
    private func makeMenu() -> UIMenu {
        var children: [UIMenuElement] = [
            makeSelectAction(),
            makeSortMenu()
        ]

        if let onExport {
            children.append(makeExportAction(onExport))
        }

        children.append(contentsOf: [
            makeAddMenu(),
            makeEditMenu()
        ])
        let menu = UIMenu(children: children)

        // Разрешает системе показать title и subtitle для пункта "Сортировка".
        let displayPreferences = UIMenuDisplayPreferences()
        displayPreferences.maximumNumberOfTitleLines = 2
        menu.displayPreferences = displayPreferences

        return menu
    }

    /// Собирает вложенное меню сортировки с системной подписью выбранного режима.
    private func makeSortMenu() -> UIMenu {
        // Каждый пункт добавляется только при наличии хотя бы одного разрешённого направления.
        let children: [UIMenuElement] = [
            makeDirectionalSortMenu(
                title: String(localized: "Artist"),
                firstTitle: String(localized: "A–Z"),
                firstMode: .artistAsc,
                secondTitle: String(localized: "Z–A"),
                secondMode: .artistDesc
            ),
            makeDirectionalSortMenu(
                title: String(localized: "Title"),
                firstTitle: String(localized: "A–Z"),
                firstMode: .titleAsc,
                secondTitle: String(localized: "Z–A"),
                secondMode: .titleDesc
            ),
            makeDirectionalSortMenu(
                title: String(localized: "Album"),
                firstTitle: String(localized: "A–Z"),
                firstMode: .albumAsc,
                secondTitle: String(localized: "Z–A"),
                secondMode: .albumDesc
            ),
            makeDirectionalSortMenu(
                title: String(localized: "Year"),
                firstTitle: String(localized: "Newest First"),
                firstMode: .yearDesc,
                secondTitle: String(localized: "Oldest First"),
                secondMode: .yearAsc
            ),
            makeDirectionalSortMenu(
                title: String(localized: "Label"),
                firstTitle: String(localized: "A–Z"),
                firstMode: .labelAsc,
                secondTitle: String(localized: "Z–A"),
                secondMode: .labelDesc
            ),
            makeDirectionalSortMenu(
                title: String(localized: "Genre"),
                firstTitle: String(localized: "A–Z"),
                firstMode: .genreAsc,
                secondTitle: String(localized: "Z–A"),
                secondMode: .genreDesc
            ),
            makeSortAction(title: String(localized: "Comment"), mode: .commentAsc),
            makeDirectionalSortMenu(
                title: String(localized: "File Name"),
                firstTitle: String(localized: "A–Z"),
                firstMode: .fileNameAsc,
                secondTitle: String(localized: "Z–A"),
                secondMode: .fileNameDesc
            ),
            makeDirectionalSortMenu(
                title: String(localized: "Date"),
                firstTitle: String(localized: "Newest First"),
                firstMode: .fileDateDesc,
                secondTitle: String(localized: "Oldest First"),
                secondMode: .fileDateAsc
            )
        ].compactMap { $0 }

        let menu = UIMenu(
            title: String(localized: "Sort"),
            image: UIImage(systemName: "arrow.up.arrow.down"),
            children: children
        )
        menu.subtitle = LibraryPresentationText.trackSortModeTitle(for: selectedSortMode)
        return menu
    }

    /// Собирает подменю сортировки с двумя направлениями.
    private func makeDirectionalSortMenu(
        title: String,
        firstTitle: String,
        firstMode: LibraryTrackSortMode,
        secondTitle: String,
        secondMode: LibraryTrackSortMode
    ) -> UIMenu? {
        let modes = [firstMode, secondMode].filter { availableSortModes.contains($0) }
        guard modes.isEmpty == false else { return nil }

        return UIMenu(
            title: title,
            options: .singleSelection,
            children: modes.map { mode in
                makeSortAction(
                    title: mode == firstMode ? firstTitle : secondTitle,
                    mode: mode
                )
            }
        )
    }

    /// Собирает пункт сортировки с checkmark для текущего режима.
    private func makeSortAction(
        title: String,
        mode: LibraryTrackSortMode
    ) -> UIAction {
        UIAction(
            title: title,
            state: selectedSortMode == mode ? .on : .off
        ) { _ in
            onSortModeSelection(mode)
        }
    }

    /// Собирает пункт входа в режим выбора.
    private func makeSelectAction() -> UIAction {
        UIAction(
            title: String(localized: "Select"),
            image: UIImage(systemName: "checkmark.circle")
        ) { _ in
            onSelect()
        }
    }

    /// Собирает пункт экспорта всех видимых треков текущей папки.
    private func makeExportAction(_ onExport: @escaping () -> Void) -> UIAction {
        UIAction(
            title: String(localized: "Export"),
            image: UIImage(systemName: "externaldrive"),
            attributes: isExportEnabled ? [] : [.disabled]
        ) { _ in
            onExport()
        }
    }

    /// Собирает inline-группу добавления выбранных треков.
    private func makeAddMenu() -> UIMenu {
        UIMenu(
            title: String(localized: "Add"),
            options: .displayInline,
            children: [
                makeBatchAction(.addToPlayer, imageName: "waveform"),
                makeBatchAction(.addToTrackList, imageName: "list.star")
            ]
        )
    }

    /// Собирает inline-группу изменения выбранных треков.
    private func makeEditMenu() -> UIMenu {
        UIMenu(
            title: String(localized: "Edit"),
            options: .displayInline,
            children: [
                makeBatchAction(.renameFiles, imageName: "pencil"),
                makeBatchAction(.editTags, imageName: "tag")
            ]
        )
    }

    /// Собирает пункт batch-действия, оставляя выполнение во ViewModel.
    private func makeBatchAction(
        _ action: BulkTrackAction,
        imageName: String
    ) -> UIAction {
        UIAction(
            title: LibraryPresentationText.bulkActionTitle(for: action),
            image: UIImage(systemName: imageName)
        ) { _ in
            onBatchActionSelection(action)
        }
    }
}
