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
    /// Подпапки текущей папки, которые нужно показать над секциями треков.
    let subfolders: [LibraryFolder]
    /// Передаёт навигационное действие владельцу flow фонотеки.
    let onSubfolderTap: (LibraryFolder) -> Void
    /// Передаёт видимые треки для экспорта владельцу flow папки.
    let onExportTracks: ([LibraryTrack]) -> Void
    let revealRequest: LibraryRevealRequest?
    let onRevealHandled: (UUID) -> Void
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?

    @ObservedObject var playerViewModel: PlayerViewModel
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var sheetManager: SheetManager
    @StateObject private var tracksViewModel: LibraryTracksViewModel
    @StateObject private var cloudAvailabilityController = CloudTrackAvailabilityController()
    @StateObject private var scrollSpeed = ScrollSpeedModel(thresholdPtPerSec: 1500,debounceMs: 180)
    @StateObject private var revealCoordinator: LibraryTrackRevealCoordinator
    private let selectionActionBarCoordinator = LibrarySelectionActionBarCoordinator()
    private let sheetCoordinator = LibraryTracksSheetCoordinator()

    // MARK: -  Локальное состояние для скролла
    
    @State private var scrollRequest: LibraryScrollRequest?

    /// Показывает, активен ли локальный режим выбора фонотеки.
    private var isSelecting: Bool {
        tracksViewModel.bulkSelection.isActive
    }

    /// Пробрасывает selection в список без переноса логики выбора в строки.
    private var selectionBinding: Binding<OrderedSelection<UUID>> {
        Binding(
            get: { tracksViewModel.bulkSelection.selection },
            set: { tracksViewModel.bulkSelection.selection = $0 }
        )
    }

    /// Все видимые треки текущих секций для передачи в строки списком контекста.
    private var allVisibleTracks: [LibraryTrack] {
        tracksViewModel.trackSections.flatMap(\.tracks)
    }
    
    // MARK: - Init
    
    init(
        folder: LibraryFolder,
        subfolders: [LibraryFolder] = [],
        onSubfolderTap: @escaping (LibraryFolder) -> Void = { _ in },
        onExportTracks: @escaping ([LibraryTrack]) -> Void = { _ in },
        revealRequest: LibraryRevealRequest? = nil,
        onRevealHandled: @escaping (UUID) -> Void = { _ in },
        playerViewModel: PlayerViewModel,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?> = .constant(nil)
    ) {
        self.folder = folder
        self.subfolders = subfolders
        self.onSubfolderTap = onSubfolderTap
        self.onExportTracks = onExportTracks
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self.playerViewModel = playerViewModel
        self._selectionActionBarConfig = selectionActionBarConfig
        self._revealCoordinator = StateObject(
            wrappedValue: LibraryTrackRevealCoordinator(
                initialRequest: revealRequest
            )
        )
        self._tracksViewModel = StateObject(
            wrappedValue: LibraryTracksViewModel(
                folderURL: folder.url,
                renameActionHandler: TrackFileRenameActionHandler(
                    playerManager: playerViewModel.fileOperationPlayerManager,
                    sheetManager: SheetManager.shared,
                    commandExecutor: AppCommandExecutor.shared,
                    toastManager: ToastManager.shared,
                    proposalBuilder: FileRenameProposalBuilder()
                )
            )
        )
    }

    // MARK: - Ui

    var body: some View {
        contentView
            // Навигационный toolbar подключается снаружи списка, чтобы не влиять на строки.
            .navigationTitle(folder.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                navigationToolbarContent
            }
            .refreshable {
                await tracksViewModel.refresh()
            }
            .task {
                await tracksViewModel.loadTracksIfNeeded()
                handleRevealDecision(
                    revealCoordinator.evaluateReveal(
                        trackSections: tracksViewModel.trackSections,
                        didLoad: tracksViewModel.didLoad,
                        isLoading: tracksViewModel.isLoading
                    )
                )
            }
            .onChange(of: revealRequest?.requestId) { _, _ in
                handleRevealDecision(
                    revealCoordinator.receiveRevealRequest(
                        revealRequest,
                        trackSections: tracksViewModel.trackSections,
                        didLoad: tracksViewModel.didLoad,
                        isLoading: tracksViewModel.isLoading
                    )
                )
            }
            .onChange(of: sheetManager.dismissCounter) { _, _ in
                handleSheetDismissCounterChange()
            }
            .onChange(of: tracksViewModel.bulkSelection.selectedCount) { _, _ in
                updateSelectionActionBarConfig()
            }
            .onChange(of: tracksViewModel.batchFilenameRenameFlow.isActive) { _, isActive in
                handleBatchFilenameRenameFlowActivityChange(isActive)
            }
            .onDisappear {
                selectionActionBarConfig = nil
            }
    }

    // Контент справа отдаёт наружу только пользовательские намерения.
    @ToolbarContentBuilder
    private var navigationToolbarContent: some ToolbarContent {
        if isSelecting {

            // Меню batch-действий в режиме выбора.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: handleToggleSelectAll) {
                        Label(
                            tracksViewModel.areAllVisibleTracksSelected ? "Снять все" : "Выбрать все",
                            systemImage: tracksViewModel.areAllVisibleTracksSelected ? "circle" : "checkmark.circle"
                        )
                    }

                    Divider()

                    batchActionMenuItems
                } label: {
                    Image(systemName: "ellipsis")
                }
            }

            /// Закрывает режим выбора и очищает текущий selection.
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: handleTapCancel) {
                    Image(systemName: "xmark")
                }
            }

        } else {

            /// Меню обычного режима.
            ToolbarItem(placement: .topBarTrailing) {
                LibraryTracksToolbarMenuButton(
                    selectedSortMode: tracksViewModel.sortMode,
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

    /// Общие пункты batch-действий без выполнения самих действий.
    @ViewBuilder
    private var batchActionMenuItems: some View {
        // Системные секции меню выравнивают заголовки отдельно от пунктов с иконками.
        Section("Добавить") {
            Button {
                handleBatchActionSelection(.addToPlayer)
            } label: {
                Label("В плеер", systemImage: "waveform")
            }

            Button {
                handleBatchActionSelection(.addToTrackList)
            } label: {
                Label("В треклист", systemImage: "list.star")
            }
        }

        Section("Изменить") {
            Button {
                handleBatchActionSelection(.renameFiles)
            } label: {
                Label("Имя файла", systemImage: "pencil")
            }

            Button {
                handleBatchActionSelection(.editTags)
            } label: {
                Label("Теги", systemImage: "tag")
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
                    sections: tracksViewModel.trackSections,
                    allTracks: allVisibleTracks,
                    playbackSource: .libraryFolder(id: folder.id),
                    trackListNamesById: tracksViewModel.trackListNamesById,
                    metadataProvider: tracksViewModel,
                    cloudAvailabilityController: cloudAvailabilityController,
                    playerViewModel: playerViewModel,
                    isScrollingFast: scrollSpeed.isFast,
                    revealedTrackID: revealCoordinator.revealedTrackID,
                    onRenameTrack: { trackId, strategy in
                        tracksViewModel.renameTrack(
                            trackId: trackId,
                            strategy: strategy
                        )
                    },
                    isSelecting: isSelecting,
                    selection: selectionBinding
                )
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            .onAppear {
                handleTracksListAppear()
            }
            // Как только появилась цель — скроллим.
            .onChange(of: scrollRequest) { _, request in
                handleScrollRequest(request, proxy: proxy)
            }
            .onChange(of: tracksViewModel.trackSections) { _, _ in
                handleRevealDecision(
                    revealCoordinator.evaluateReveal(
                        trackSections: tracksViewModel.trackSections,
                        didLoad: tracksViewModel.didLoad,
                        isLoading: tracksViewModel.isLoading
                    )
                )
            }
            .onChange(of: playerViewModel.currentTrackDisplayable?.id) { _, _ in
                requestActiveTrackScrollIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
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
        if tracksViewModel.isLoading && tracksViewModel.trackSections.isEmpty {
            VStack {
                Spacer()
                ProgressView("Загружаю треки")
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
        requestActiveTrackScrollIfNeeded()
        updateSelectionActionBarConfig()
    }

    /// Обрабатывает нажатие выбора в toolbar.
    private func handleTapSelect() {
        // Вход в выбор без заранее выбранного batch-действия.
        tracksViewModel.activateBulkSelection()
        updateSelectionActionBarConfig()
    }

    /// Передаёт треки в текущем отображаемом порядке обработчику папки.
    private func handleTapExport() {
        guard allVisibleTracks.isEmpty == false else { return }
        onExportTracks(allVisibleTracks)
    }

    /// Обрабатывает массовое переключение выбора в toolbar.
    private func handleToggleSelectAll() {
        // Массовое переключение выбора остаётся во ViewModel.
        tracksViewModel.toggleSelectAllVisibleTracks()
        updateSelectionActionBarConfig()
    }

    /// Обрабатывает выбор режима сортировки из toolbar menu.
    private func handleSortModeSelection(_ mode: LibraryTrackSortMode) {
        Task {
            await tracksViewModel.setSortMode(mode)
        }
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

    /// Обновляет список после закрытия глобального sheet.
    private func handleSheetDismissCounterChange() {
        guard sheetCoordinator.shouldRefreshAfterDismiss(
            lastDismissedSheetKind: sheetManager.lastDismissedSheetKind,
            isLoading: tracksViewModel.isLoading
        ) else {
            return
        }

        Task {
            await tracksViewModel.refresh()
        }
    }

    /// Открывает глобальный sheet при запуске flow массового переименования.
    private func handleBatchFilenameRenameFlowActivityChange(_ isActive: Bool) {
        guard sheetCoordinator.shouldPresentBatchFilenameRename(
            isActive: isActive
        ) else {
            return
        }

        sheetManager.presentBatchFilenameRename(
            flow: tracksViewModel.batchFilenameRenameFlow,
            playerManager: playerViewModel.fileOperationPlayerManager,
            onApply: {
                await tracksViewModel.applyBatchFilenameRename(
                    using: playerViewModel.fileOperationPlayerManager
                )
            }
        )
    }

    /// Синхронизирует конфигурацию нижней панели подтверждения для родительского host.
    private func updateSelectionActionBarConfig() {
        selectionActionBarConfig = selectionActionBarCoordinator.makeConfig(
            pendingAction: tracksViewModel.bulkSelection.pendingAction,
            selectedCount: tracksViewModel.bulkSelection.selectedCount,
            hasSelection: tracksViewModel.bulkSelection.hasSelection,
            onPrimaryTap: applySelectedBatchAction
        )
    }

    /// Сбрасывает режим мультиселекта и очищает нижнюю панель.
    private func resetMultiselect() {
        tracksViewModel.resetBulkSelection()
        updateSelectionActionBarConfig()
    }

    /// Обрабатывает выбор batch-действия с учётом текущего режима и выбора.
    private func handleBatchActionSelection(_ action: BulkTrackAction) {
        tracksViewModel.selectBulkAction(action)
        updateSelectionActionBarConfig()
    }

    /// Применяет заранее выбранное batch-действие из нижней панели.
    private func applySelectedBatchAction() {
        tracksViewModel.applyPendingBulkAction()
        updateSelectionActionBarConfig()
    }

    /// Запрашивает прокрутку к активному треку, если она не конфликтует с reveal.
    private func requestActiveTrackScrollIfNeeded() {
        guard let request = revealCoordinator.activeTrackScrollRequestIfNeeded(
            currentTrack: playerViewModel.currentTrackDisplayable,
            currentContext: playerViewModel.currentContext,
            trackSections: tracksViewModel.trackSections,
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

    // MARK: - Init

    /// Создаёт меню действий списка с необязательным пунктом экспорта.
    init(
        selectedSortMode: LibraryTrackSortMode,
        availableSortModes: [LibraryTrackSortMode],
        onSelect: @escaping () -> Void,
        onSortModeSelection: @escaping (LibraryTrackSortMode) -> Void,
        onBatchActionSelection: @escaping (BulkTrackAction) -> Void,
        onExport: (() -> Void)? = nil,
        isExportEnabled: Bool = false,
        accessibilityLabel: String = "Действия папки фонотеки"
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
                title: "Артист",
                firstTitle: "От А до Я",
                firstMode: .artistAsc,
                secondTitle: "От Я до А",
                secondMode: .artistDesc
            ),
            makeDirectionalSortMenu(
                title: "Название",
                firstTitle: "От А до Я",
                firstMode: .titleAsc,
                secondTitle: "От Я до А",
                secondMode: .titleDesc
            ),
            makeDirectionalSortMenu(
                title: "Альбом",
                firstTitle: "От А до Я",
                firstMode: .albumAsc,
                secondTitle: "От Я до А",
                secondMode: .albumDesc
            ),
            makeDirectionalSortMenu(
                title: "Год",
                firstTitle: "Сначала новые",
                firstMode: .yearDesc,
                secondTitle: "Сначала старые",
                secondMode: .yearAsc
            ),
            makeDirectionalSortMenu(
                title: "Лейбл",
                firstTitle: "От А до Я",
                firstMode: .labelAsc,
                secondTitle: "От Я до А",
                secondMode: .labelDesc
            ),
            makeDirectionalSortMenu(
                title: "Жанр",
                firstTitle: "От А до Я",
                firstMode: .genreAsc,
                secondTitle: "От Я до А",
                secondMode: .genreDesc
            ),
            makeSortAction(title: "Комментарий", mode: .commentAsc),
            makeDirectionalSortMenu(
                title: "Название файла",
                firstTitle: "От А до Я",
                firstMode: .fileNameAsc,
                secondTitle: "От Я до А",
                secondMode: .fileNameDesc
            ),
            makeDirectionalSortMenu(
                title: "Дата",
                firstTitle: "Сначала новые",
                firstMode: .fileDateDesc,
                secondTitle: "Сначала старые",
                secondMode: .fileDateAsc
            )
        ].compactMap { $0 }

        let menu = UIMenu(
            title: "Сортировка",
            image: UIImage(systemName: "arrow.up.arrow.down"),
            children: children
        )
        menu.subtitle = selectedSortMode.title
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
            title: "Выбрать",
            image: UIImage(systemName: "checkmark.circle")
        ) { _ in
            onSelect()
        }
    }

    /// Собирает пункт экспорта всех видимых треков текущей папки.
    private func makeExportAction(_ onExport: @escaping () -> Void) -> UIAction {
        UIAction(
            title: "Экспорт",
            image: UIImage(systemName: "externaldrive"),
            attributes: isExportEnabled ? [] : [.disabled]
        ) { _ in
            onExport()
        }
    }

    /// Собирает inline-группу добавления выбранных треков.
    private func makeAddMenu() -> UIMenu {
        UIMenu(
            title: "Добавить",
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
            title: "Изменить",
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
            title: action.title,
            image: UIImage(systemName: imageName)
        ) { _ in
            onBatchActionSelection(action)
        }
    }
}
