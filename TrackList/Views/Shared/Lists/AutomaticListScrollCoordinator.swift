//
//  AutomaticListScrollCoordinator.swift
//  TrackList
//
//  Координирует локальную политику автоматической прокрутки SwiftUI-списка.
//
//  Created by Pavel Fomin on 21.08.2026.
//

import SwiftUI

/// Нормализует системные фазы SwiftUI до состояний, важных для политики списка.
enum ListScrollPhase: Equatable {
    /// Список не прокручивается.
    case idle
    /// Пользователь удерживает, прокручивает или завершает инерционную прокрутку списка.
    case userInteraction
    /// SwiftUI анимирует программную прокрутку.
    case programmaticAnimation

    /// Преобразует системную фазу без раскрытия SwiftUI API в policy-тестах.
    init(_ phase: ScrollPhase) {
        switch phase {
        case .idle:
            self = .idle

        case .animating:
            self = .programmaticAnimation

        case .tracking,
             .interacting,
             .decelerating:
            self = .userInteraction
        }
    }
}

/// Управляет только UI-правилами автоматического scroll, не владея `ScrollViewProxy`.
@MainActor
final class AutomaticListScrollCoordinator: ObservableObject {

    /// Одноразовая команда View выполнить автоматическую прокрутку к доступной строке.
    struct Request: Equatable, Identifiable {
        /// Семантика запроса определяет его приоритет относительно ручной позиции и reveal.
        enum Kind: Equatable {
            /// Пассивная смена active track не должна возвращать список после ручной прокрутки.
            case automatic
            /// Явная навигация MiniPlayer должна дождаться idle, если список занят пальцем или инерцией.
            case explicitPlaybackNavigation(triggerId: UUID)
        }

        /// Отдельная identity одной команды не смешивается с identity строки feature.
        let id: UUID
        /// Непрозрачный для coordinator идентификатор строки текущего feature.
        let targetId: UUID
        /// Определяет, должна ли View анимировать переход.
        let isAnimated: Bool
        /// Причина определяет, можно ли отложить request вместо его отмены.
        let kind: Kind
    }

    /// Текущее состояние единственного программного scroll lifecycle списка.
    enum State: Equatable {
        /// Нет принятой команды и пользователь не взаимодействует со списком.
        case idle
        /// Auto-scroll принят, но View ещё не вызвала `scrollTo`.
        case automaticPending(Request)
        /// Явная навигация MiniPlayer принята, но View ещё не вызвала `scrollTo`.
        case explicitPlaybackNavigationPending(Request)
        /// View уже вызвала `scrollTo`; следующий request ждёт системного возврата к idle.
        case programmatic
        /// Приоритет принадлежит физическому взаимодействию пользователя со списком.
        case userInteracting
    }

    /// Запоминает, оставил ли пользователь осознанную позицию в текущем lifecycle списка.
    enum UserPosition: Equatable {
        /// Экран ещё может показать active track автоматически.
        case initial
        /// После ручной прокрутки auto-scroll больше не возвращает список без нового явного intent.
        case manuallyPositioned
    }

    // MARK: - Состояние

    /// Единый источник истины о принятом или выполняемом scroll-запросе.
    /// Технические фазы не публикуются, чтобы не инвалидировать большой List во время жеста.
    private(set) var state: State = .idle
    /// История ручной позиции заменяет неустойчивый cooldown с фиксированной задержкой.
    private(set) var userPosition: UserPosition = .initial
    /// Единственное наблюдаемое изменение: команда, которую View должна materialize через ScrollViewProxy.
    @Published private(set) var pendingScrollRequest: Request?

    /// Первое появление destination допускает отдельный auto-scroll к active track.
    private var didHandleInitialAppearance = false
    /// Повторная доставка того же active target не создаёт второй request.
    private var lastAutomaticTargetId: UUID?
    /// Повторный rebuild ScreenState не материализует один и тот же явный MiniPlayer intent дважды.
    private var lastExplicitPlaybackNavigationTriggerId: UUID?
    /// Единственный новый explicit target ожидает idle после пальца, инерции или чужой programmatic animation.
    private var deferredExplicitPlaybackNavigationRequest: Request?

    /// Явный reveal может начаться только вне физического и уже выполняемого программного scroll.
    var canBeginRevealScroll: Bool {
        switch state {
        case .idle,
             .automaticPending,
             .explicitPlaybackNavigationPending:
            return true

        case .programmatic,
             .userInteracting:
            return false
        }
    }

    // MARK: - Запросы auto-scroll

    /// Принимает initial scroll только один раз на lifecycle View.
    @discardableResult
    func requestInitialScrollIfNeeded(
        targetId: UUID?,
        isTargetAvailable: Bool
    ) -> Request? {
        guard didHandleInitialAppearance == false else {
            return nil
        }

        didHandleInitialAppearance = true

        return requestAutomaticScroll(
            targetId: targetId,
            isTargetAvailable: isTargetAvailable,
            isAnimated: false
        )
    }

    /// Принимает смену active track, если она не нарушает осознанную позицию пользователя.
    @discardableResult
    func requestActiveTrackScrollIfNeeded(
        targetId: UUID?,
        isTargetAvailable: Bool
    ) -> Request? {
        guard userPosition == .initial else {
            return nil
        }

        return requestAutomaticScroll(
            targetId: targetId,
            isTargetAvailable: isTargetAvailable,
            isAnimated: true
        )
    }

    /// Резервирует единственный auto-scroll после проверки feature-local identity строки.
    private func requestAutomaticScroll(
        targetId: UUID?,
        isTargetAvailable: Bool,
        isAnimated: Bool
    ) -> Request? {
        guard let targetId, isTargetAvailable else {
            return nil
        }
        guard lastAutomaticTargetId != targetId else {
            return nil
        }
        guard case .idle = state else {
            return nil
        }

        let request = makeRequest(
            targetId: targetId,
            isAnimated: isAnimated,
            kind: .automatic
        )
        state = .automaticPending(request)
        pendingScrollRequest = request
        return request
    }

    /// Фиксирует вызов `scrollTo` и не допускает второй программный scroll до завершения анимации.
    func beginScroll(
        _ request: Request
    ) -> Bool {
        guard isPending(request) else {
            return false
        }

        if request.kind == .automatic {
            lastAutomaticTargetId = request.targetId
        }
        state = .programmatic
        pendingScrollRequest = nil
        return true
    }

    /// Отменяет request, если target исчез до materialization во View.
    func rejectScroll(
        _ request: Request
    ) {
        guard isPending(request) else {
            return
        }

        state = .idle
        pendingScrollRequest = nil
        _ = materializeDeferredExplicitPlaybackNavigationIfPossible()
    }

    // MARK: - Явная навигация MiniPlayer

    /// Принимает explicit navigation независимо от ручной позиции и откладывает её до idle при занятом списке.
    @discardableResult
    func requestExplicitPlaybackNavigationScrollIfNeeded(
        triggerId: UUID,
        targetId: UUID?,
        isTargetAvailable: Bool
    ) -> Request? {
        guard let targetId, isTargetAvailable else {
            return nil
        }
        guard lastExplicitPlaybackNavigationTriggerId != triggerId else {
            return nil
        }

        let request = makeRequest(
            targetId: targetId,
            isAnimated: true,
            kind: .explicitPlaybackNavigation(triggerId: triggerId)
        )
        lastExplicitPlaybackNavigationTriggerId = triggerId

        switch state {
        case .idle,
             .automaticPending:
            // Явная навигация вытесняет ещё не materialized passive auto-scroll.
            state = .explicitPlaybackNavigationPending(request)
            pendingScrollRequest = request
            return request

        case .explicitPlaybackNavigationPending:
            // Несколько быстрых Next/Previous заменяют target до вызова `scrollTo`.
            state = .explicitPlaybackNavigationPending(request)
            pendingScrollRequest = request
            return request

        case .programmatic,
             .userInteracting:
            // Последняя явная команда сохраняется локально и будет опубликована только после idle.
            deferredExplicitPlaybackNavigationRequest = request
            return nil
        }
    }

    // MARK: - Явная прокрутка reveal

    /// Резервирует scroll для reveal, вытесняя ещё не materialized auto-scroll.
    func beginRevealScroll() -> Bool {
        guard canBeginRevealScroll else {
            return false
        }

        discardExplicitPlaybackNavigationForReveal()
        state = .programmatic
        pendingScrollRequest = nil
        return true
    }

    /// Отдаёт приоритет ожидающему reveal до перехода списка в idle, чтобы deferred MiniPlayer intent не опередил navigation.
    func discardExplicitPlaybackNavigationForReveal() {
        deferredExplicitPlaybackNavigationRequest = nil

        if case .explicitPlaybackNavigationPending = state {
            state = .idle
            pendingScrollRequest = nil
        }
    }

    /// Завершает неанимированный scroll синхронно; анимированный ждёт системную фазу idle.
    func finishProgrammaticScroll(
        isAnimated: Bool
    ) {
        guard case .programmatic = state else {
            return
        }

        if isAnimated == false {
            state = .idle
            _ = materializeDeferredExplicitPlaybackNavigationIfPossible()
        }
    }

    /// Освобождает ошибочно зарезервированный explicit scroll, если reveal устарел до вызова `scrollTo`.
    func cancelExplicitScrollReservation() {
        guard case .programmatic = state else {
            return
        }

        state = .idle
        _ = materializeDeferredExplicitPlaybackNavigationIfPossible()
    }

    // MARK: - Системный lifecycle списка

    /// Применяет системную фазу и возвращает отложенную явную команду ровно в момент освобождения списка.
    /// View может materialize её синхронно, не полагаясь на вложенный цикл наблюдения SwiftUI.
    @discardableResult
    func receiveScrollPhase(
        _ phase: ListScrollPhase
    ) -> Request? {
        switch phase {
        case .idle:
            // Pending request ещё не дошёл до обработчика View и не должен теряться из-за idle callback.
            switch state {
            case .programmatic,
                 .userInteracting:
                state = .idle
                return materializeDeferredExplicitPlaybackNavigationIfPossible()

            case .idle,
                 .automaticPending,
                 .explicitPlaybackNavigationPending:
                return nil
            }

        case .userInteraction:
            userPosition = .manuallyPositioned
            if case .explicitPlaybackNavigationPending(let request) = state {
                // В отличие от passive auto-scroll, явная команда не теряется при новом жесте.
                deferredExplicitPlaybackNavigationRequest = request
            }
            state = .userInteracting
            // Не materialize уже принятую, но ещё не выполненную команду после начала жеста.
            if pendingScrollRequest != nil {
                pendingScrollRequest = nil
            }
            return nil

        case .programmaticAnimation:
            state = .programmatic
            return nil
        }
    }

    // MARK: - Внутренняя координация

    /// Создаёт локальную команду, не раскрывая View разницу между passive и explicit policy.
    private func makeRequest(
        targetId: UUID,
        isAnimated: Bool,
        kind: Request.Kind
    ) -> Request {
        Request(
            id: UUID(),
            targetId: targetId,
            isAnimated: isAnimated,
            kind: kind
        )
    }

    /// Проверяет, что request остаётся текущей командой и старый View callback не сможет её выполнить.
    private func isPending(
        _ request: Request
    ) -> Bool {
        switch state {
        case .automaticPending(let pendingRequest),
             .explicitPlaybackNavigationPending(let pendingRequest):
            pendingRequest == request

        case .idle,
             .programmatic,
             .userInteracting:
            false
        }
    }

    /// Публикует и возвращает сохранённую explicit navigation после освобождения списка от физической или иной programmatic прокрутки.
    private func materializeDeferredExplicitPlaybackNavigationIfPossible() -> Request? {
        guard case .idle = state,
              let request = deferredExplicitPlaybackNavigationRequest else {
            return nil
        }

        deferredExplicitPlaybackNavigationRequest = nil
        state = .explicitPlaybackNavigationPending(request)
        pendingScrollRequest = request
        return request
    }
}
