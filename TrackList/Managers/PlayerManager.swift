//
//  PlayerManager.swift
//  TrackList
//
//  Управляет воспроизведением через AVPlayer.
//  - доступ к файлам (security-scoped URL)
//  - подготовка и воспроизведение
//  - прогресс воспроизведения
//  - Now Playing Info
//  - уведомления trackDidFinish / trackDurationUpdated
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import Combine
// MediaPlayer предоставляет синхронные system callbacks без полной Sendable-аннотации.
// Граница локализована в PlayerManager, который владеет всеми MediaPlayer token-ами на MainActor.
@preconcurrency import MediaPlayer
// AVFoundation callbacks также входят в PlayerManager только через явный MainActor bridge.
@preconcurrency import AVFoundation

/// Общий интервал обновления пользовательского progress без отдельного визуального таймера.
enum PlayerProgressObservationConfiguration {

    /// Четыре обновления в секунду делают waveform плавной, не приближаясь к кадровой частоте интерфейса.
    static let interval: TimeInterval = 0.25
}

/// Изолирует AVPlayer API для контролируемых XCTest без переноса ownership из PlayerManager.
@MainActor
protocol PlayerRuntimeControlling: AnyObject {
    var currentItem: AVPlayerItem? { get }
    func replaceCurrentItem(with item: AVPlayerItem?)
    func play()
    func pause()
    func seek(
        to time: CMTime,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completionHandler: @escaping @Sendable (Bool) -> Void
    )
    func seek(to time: CMTime)
    func addPeriodicTimeObserver(
        forInterval interval: CMTime,
        queue: DispatchQueue,
        using block: @escaping @Sendable (CMTime) -> Void
    ) -> Any
    func removeTimeObserver(_ observer: Any)
}

/// Production-обёртка сохраняет прямой AVPlayer lifecycle в единственном PlayerManager runtime.
@MainActor
private final class AVPlayerRuntime: PlayerRuntimeControlling {

    private let player = AVPlayer()

    var currentItem: AVPlayerItem? {
        player.currentItem
    }

    func replaceCurrentItem(with item: AVPlayerItem?) {
        player.replaceCurrentItem(with: item)
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func seek(
        to time: CMTime,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        player.seek(
            to: time,
            toleranceBefore: toleranceBefore,
            toleranceAfter: toleranceAfter,
            completionHandler: completionHandler
        )
    }

    func seek(to time: CMTime) {
        player.seek(to: time)
    }

    func addPeriodicTimeObserver(
        forInterval interval: CMTime,
        queue: DispatchQueue,
        using block: @escaping @Sendable (CMTime) -> Void
    ) -> Any {
        player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: queue,
            using: block
        )
    }

    func removeTimeObserver(_ observer: Any) {
        player.removeTimeObserver(observer)
    }
}

/// Передаёт PlayerManager готовый playback URL и явный security-scope contract источника.
struct PlayerPlaybackResource {
    let url: URL
    let needsSecurityScopedAccess: Bool
}

/// Позволяет production-коду и controlled XCTest одинаково разрешать источник playback.
@MainActor
protocol PlayerPlaybackResourceResolving: AnyObject {
    func resolvePlaybackResource(
        for track: any TrackDisplayable
    ) async throws -> PlayerPlaybackResource
}

/// Production-resolver сохраняет раздельные contracts purchased iTunes и bookmark-файлов.
@MainActor
private final class DefaultPlayerPlaybackResourceResolver: PlayerPlaybackResourceResolving {

    func resolvePlaybackResource(
        for track: any TrackDisplayable
    ) async throws -> PlayerPlaybackResource {
        if let purchasedTrack = track as? PurchasedITunesPlayableTrack {
            // Трек iTunes приходит из MediaPlayer с готовым assetURL, поэтому BookmarkResolver здесь не нужен.
            return PlayerPlaybackResource(
                url: purchasedTrack.assetURL,
                needsSecurityScopedAccess: false
            )
        }

        guard let resolvedURL = await BookmarkResolver.url(forTrack: track.trackId) else {
            PersistentLogger.log("❌ PlayerManager: no URL for trackId=\(track.trackId)")
            throw AppError.bookmarkResolveFailed
        }

        return PlayerPlaybackResource(
            url: resolvedURL,
            needsSecurityScopedAccess: true
        )
    }
}

/// Сохраняет AVAsset.load асинхронным и позволяет тесту точно контролировать suspension boundary.
@MainActor
protocol PlayerAssetLoading: AnyObject {
    func loadIsPlayable(for item: AVPlayerItem) async throws
    func loadDuration(for item: AVPlayerItem) async -> TimeInterval
}

/// Production-loader не выполняет синхронное файловое чтение на MainActor.
@MainActor
private final class AVPlayerAssetLoader: PlayerAssetLoading {

    func loadIsPlayable(for item: AVPlayerItem) async throws {
        _ = try await item.asset.load(.isPlayable)
    }

    func loadDuration(for item: AVPlayerItem) async -> TimeInterval {
        (try? await item.asset.load(.duration))?.seconds ?? 0
    }
}

/// Узкая capability security-scoped URL отделяет временный доступ одного request от текущего доступа PlayerManager.
@MainActor
protocol PlayerSecurityScopedResourceAccessing: AnyObject {
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

/// Production-accessor вызывает только системный URL security-scope API.
@MainActor
private final class URLSecurityScopedResourceAccessor: PlayerSecurityScopedResourceAccessing {

    func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

@MainActor
final class PlayerManager {

    // MARK: - Приватное

    /// Единственный runtime AVPlayer принадлежит MainActor-изолированному PlayerManager.
    private let player: any PlayerRuntimeControlling
    private let playbackResourceResolver: any PlayerPlaybackResourceResolving
    private let assetLoader: any PlayerAssetLoading
    private let securityScopedResourceAccessor: any PlayerSecurityScopedResourceAccessing
    private let notificationCenter: NotificationCenter
    private var timeObserverToken: Any?
    private var finishObserver: NSObjectProtocol?
    private var currentAccessedURL: URL?
    /// URL сохраняется после успешной подготовки AVPlayerItem и используется только связанными runtime-сценариями.
    private var currentPreparedURL: URL?
    /// Target-ы системных playback-команд, принадлежащие этому экземпляру PlayerManager.
    private var remoteCommandTargets: [(command: MPRemoteCommand, token: Any)] = []
    /// Target системной команды «Избранное», который удаляется отдельно при повторной настройке.
    private var favoriteCommandTarget: Any?
    /// Identity текущего пользовательского запуска принадлежит фактическому AVPlayer lifecycle, а не trackId.
    private var activePlaybackRequestID: PlaybackRequestID?
    /// Request установленного item нужен для защиты finish, progress и restart callback от старого lifecycle.
    private var currentItemPlaybackRequestID: PlaybackRequestID?
    /// Текущий item хранится вместе с его request identity и доступен XCTest только для проверки уведомлений AVFoundation.
    private(set) var currentPlaybackItem: AVPlayerItem?

    // MARK: - Состояние трека

    /// ID текущего трека, загруженного в плеер (не обязательно играет).
    private(set) var currentTrackId: UUID?

    /// Флаг, что плеер сейчас воспроизводит трек.
    private(set) var isPlaying: Bool = false

    // MARK: - Инициализация

    init(
        player: (any PlayerRuntimeControlling)? = nil,
        playbackResourceResolver: (any PlayerPlaybackResourceResolving)? = nil,
        assetLoader: (any PlayerAssetLoading)? = nil,
        securityScopedResourceAccessor: (any PlayerSecurityScopedResourceAccessing)? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        self.player = player ?? AVPlayerRuntime()
        self.playbackResourceResolver = playbackResourceResolver ?? DefaultPlayerPlaybackResourceResolver()
        self.assetLoader = assetLoader ?? AVPlayerAssetLoader()
        self.securityScopedResourceAccessor = securityScopedResourceAccessor ?? URLSecurityScopedResourceAccessor()
        self.notificationCenter = notificationCenter
        print("🧠 PlayerManager инициализирован")

        // Доставка на main queue сохраняет actor boundary и позволяет проверить object текущего AVPlayerItem.
        finishObserver = notificationCenter.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // В callback переносим только immutable identity AVPlayerItem, не сам framework object.
            let finishedItemID = (notification.object as? AVPlayerItem).map(ObjectIdentifier.init)
            Task { @MainActor [weak self] in
                self?.handlePlayerItemDidFinish(itemID: finishedItemID)
            }
        }
    }

    isolated deinit {
        if let finishObserver {
            notificationCenter.removeObserver(finishObserver)
        }

        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
        }
        for target in remoteCommandTargets {
            target.command.removeTarget(target.token)
        }
        let favoriteCommand = MPRemoteCommandCenter.shared().likeCommand
        if let favoriteCommandTarget {
            favoriteCommand.removeTarget(favoriteCommandTarget)
        }
        favoriteCommand.isEnabled = false
        favoriteCommand.isActive = false
    }

    // MARK: - Уведомление о завершении

    /// Принимает завершение только item актуального request, поэтому старый AVPlayerItem не запускает следующий трек.
    func handlePlayerItemDidFinish(_ notification: Notification) {
        let finishedItemID = (notification.object as? AVPlayerItem).map(ObjectIdentifier.init)
        handlePlayerItemDidFinish(itemID: finishedItemID)
    }

    /// Сверяет immutable identity callback item с обоими MainActor runtime-owner-ами.
    private func handlePlayerItemDidFinish(itemID: ObjectIdentifier?) {
        guard let itemID,
              let playerItem = player.currentItem,
              let playbackItem = currentPlaybackItem,
              ObjectIdentifier(playerItem) == itemID,
              ObjectIdentifier(playbackItem) == itemID,
              currentItemPlaybackRequestID == activePlaybackRequestID
        else {
            return
        }

        // Трек доиграл до конца — считаем, что больше не играет.
        isPlaying = false
        notificationCenter.post(name: .trackDidFinish, object: nil)
    }

    // MARK: - Основное воспроизведение

    /// Регистрирует единственный актуальный запуск до первого suspension boundary.
    func beginPlaybackRequest() -> PlaybackRequestID {
        let requestID = PlaybackRequestID()
        activePlaybackRequestID = requestID
        return requestID
    }

    /// Сверяет identity с владельцем фактического AVPlayer lifecycle.
    func isCurrentPlaybackRequest(_ requestID: PlaybackRequestID) -> Bool {
        activePlaybackRequestID == requestID
    }

    /// Не позволяет внешнему lifecycle отменить request, который уже был заменён новым пользовательским намерением.
    func invalidatePlaybackRequest(_ requestID: PlaybackRequestID) {
        guard activePlaybackRequestID == requestID else {
            return
        }

        activePlaybackRequestID = nil
    }

    func play(
        requestID: PlaybackRequestID,
        track: any TrackDisplayable,
        onPreparedLocalFile: @escaping PlayerPreparedLocalFileHandler
    ) async throws -> PlaybackStartResult {
        let trackId = track.trackId

        // 1. Получаем URL воспроизведения из подходящего источника.
        let playbackResource = try await playbackResourceResolver.resolvePlaybackResource(for: track)
        guard isCurrentPlaybackRequest(requestID) else {
            return .superseded
        }
        let resolvedURL = playbackResource.url

        // 2. Активация аудиосессии
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            PersistentLogger.log("❌ PlayerManager: audio session failed error=\(error)")
            throw AppError.audioSessionFailed
        }
        guard isCurrentPlaybackRequest(requestID) else {
            return .superseded
        }

        // 3. Временный scope принадлежит только этому request до успешной установки item.
        var ownsTemporarySecurityScope = false
        if playbackResource.needsSecurityScopedAccess {
            // В iOS 26 (File Provider Storage) startAccessing на файл может вернуть false,
            // при этом доступ может быть получен через root-scope папки.
            let started = securityScopedResourceAccessor.startAccessing(resolvedURL)
            if started {
                ownsTemporarySecurityScope = true
            } else {
                print("⚠️ startAccessing вернул false для файла, пробуем играть через root-scope:", resolvedURL.lastPathComponent)
                PersistentLogger.log("⚠️ PlayerManager: startAccessing false file=\(resolvedURL.lastPathComponent)")
            }
        }

        defer {
            // Поздний request освобождает только scope, который открыл сам, и не трогает новый currentAccessedURL.
            if ownsTemporarySecurityScope {
                securityScopedResourceAccessor.stopAccessing(resolvedURL)
            }
        }

        guard isCurrentPlaybackRequest(requestID) else {
            return .superseded
        }

        // 4. Создаём AVPlayerItem и асинхронно проверяем его доступность.
        let item = AVPlayerItem(url: resolvedURL)
        do {
            try await assetLoader.loadIsPlayable(for: item)
        } catch {
            PersistentLogger.log("❌ PlayerManager: not playable error=\(error)")
            throw AppError.fileNotPlayable
        }
        guard isCurrentPlaybackRequest(requestID) else {
            return .superseded
        }

        // 5. Только актуальный request заменяет прежний scope и AVPlayerItem.
        stopAccessingCurrentTrack()
        if ownsTemporarySecurityScope {
            currentAccessedURL = resolvedURL
            ownsTemporarySecurityScope = false
        }
        player.replaceCurrentItem(with: item)
        player.play()
        PersistentLogger.log("▶️ PlayerManager: play started track=\(resolvedURL.lastPathComponent)")

        // Обновляем состояние текущего трека
        currentTrackId = trackId
        currentPreparedURL = resolvedURL
        currentPlaybackItem = item
        currentItemPlaybackRequestID = requestID
        isPlaying = true

        if let preparedLocalFileURL = preparedLocalFileURL(for: trackId) {
            // Контрольная точка появляется после подготовки AVPlayerItem и security scope, но до ожидания duration.
            // Менеджер сообщает только ресурс: запуск waveform остаётся ответственностью ViewModel.
            onPreparedLocalFile(
                PlayerPreparedLocalFile(
                    requestID: requestID,
                    trackId: trackId,
                    fileURL: preparedLocalFileURL
                )
            )
        }
        guard isCurrentPlaybackRequest(requestID),
              currentPlaybackItem === item,
              player.currentItem === item
        else {
            return .superseded
        }

        // 6. Длительность читается асинхронно, а после await проверяется тот же item и request.
        let duration = await assetLoader.loadDuration(for: item)
        guard isCurrentPlaybackRequest(requestID),
              currentPlaybackItem === item,
              player.currentItem === item
        else {
            return .superseded
        }

        notificationCenter.post(
            name: .trackDurationUpdated,
            object: nil,
            userInfo: ["duration": duration]
        )
        return .started
    }

    // MARK: - Доступ безопасности

    func stopAccessingCurrentTrack() {
        if let url = currentAccessedURL {
            securityScopedResourceAccessor.stopAccessing(url)
            currentAccessedURL = nil
        }

        // После освобождения scope URL закрытого доступа нельзя передавать фоновым производным операциям.
        currentPreparedURL = nil
    }

    /// Отсоединяет текущий AVPlayerItem до записи в файл и освобождает связанный security-scoped доступ.
    /// ViewModel сохраняет display-состояние трека и при следующем запуске создаст новый item по актуальному файлу.
    func releaseCurrentTrackForFileOperation() {
        // Файловая операция не должна позволить уже ожидающему request снова подключить item.
        activePlaybackRequestID = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        removeTimeObserver()
        stopAccessingCurrentTrack()
        currentTrackId = nil
        currentPlaybackItem = nil
        currentItemPlaybackRequestID = nil
        isPlaying = false
    }

    /// Возвращает только уже подготовленный локальный файл текущего AVPlayerItem.
    /// Новый bookmark и security scope здесь не создаются, чтобы waveform использовал тот же доступ, что и playback.
    func preparedLocalFileURL(for trackId: UUID) -> URL? {
        guard currentTrackId == trackId,
              let currentPreparedURL,
              currentPreparedURL.isFileURL,
              FileManager.default.fileExists(atPath: currentPreparedURL.path),
              FileManager.default.isReadableFile(atPath: currentPreparedURL.path)
        else {
            return nil
        }

        guard let resourceValues = try? currentPreparedURL.resourceValues(
            forKeys: [
                .isRegularFileKey,
                .isUbiquitousItemKey,
                .ubiquitousItemDownloadingStatusKey
            ]
        ),
              resourceValues.isRegularFile == true
        else {
            // Для iCloud placeholder не запускаем отдельную загрузку только ради waveform.
            return nil
        }

        if resourceValues.isUbiquitousItem == true {
            let downloadingStatus = resourceValues.ubiquitousItemDownloadingStatus
            let isLocallyAvailable = downloadingStatus == .current || downloadingStatus == .downloaded

            guard isLocallyAvailable else {
                // `.notDownloaded` и неизвестный статус не должны запускать отдельную загрузку ради waveform.
                return nil
            }
        }

        return currentPreparedURL
    }

    // MARK: - Элементы управления

    func pause() {
        player.pause()
        isPlaying = false
    }

    func playCurrent() {
        player.play()
        if player.currentItem != nil {
            isPlaying = true
        }
    }

    /// Перезапускает текущий item с нулевой позиции без создания нового item.
    func restartCurrent() {
        guard let item = player.currentItem,
              item === currentPlaybackItem,
              let requestID = currentItemPlaybackRequestID,
              isCurrentPlaybackRequest(requestID)
        else {
            return
        }

        player.seek(
            to: .zero,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] didFinish in
            Task { @MainActor [weak self] in
                self?.completeRestartSeek(
                    for: item,
                    requestID: requestID,
                    didFinish: didFinish
                )
            }
        }
        isPlaying = true
    }

    /// Возобновляет playback только для item и request, которые не были заменены пока AVPlayer выполнял seek.
    func completeRestartSeek(
        for item: AVPlayerItem,
        requestID: PlaybackRequestID,
        didFinish: Bool
    ) {
        guard didFinish,
              player.currentItem === item,
              currentPlaybackItem === item,
              currentItemPlaybackRequestID == requestID,
              isCurrentPlaybackRequest(requestID)
        else {
            return
        }

        player.play()
    }

    func seek(to time: TimeInterval) {
        let cm = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cm)
    }

    // MARK: - Признак занятости трека

    /// Возвращает `true`, если указанный трек сейчас загружен в плеер
    /// (даже если стоит на паузе) и держит security-scoped доступ к файлу.
    func isBusy(_ id: UUID) -> Bool {
        return currentTrackId == id && currentAccessedURL != nil
    }

    // MARK: - Прогресс

    func observeProgress(update: @escaping @MainActor @Sendable (TimeInterval) -> Void) {
        removeTimeObserver()
        let observedItem = player.currentItem
        let observedRequestID = currentItemPlaybackRequestID
        let interval = CMTimeMakeWithSeconds(
            PlayerProgressObservationConfiguration.interval,
            preferredTimescale: 600
        )

        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self,
                      self.player.currentItem === observedItem,
                      self.currentPlaybackItem === observedItem,
                      self.currentItemPlaybackRequestID == observedRequestID,
                      let observedRequestID,
                      self.isCurrentPlaybackRequest(observedRequestID)
                else {
                    return
                }

                update(time.seconds)
            }
        }
    }

    func removeTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    // MARK: - Remote Command Center

    func setupRemoteCommandCenter(
        onPlay: @escaping @MainActor @Sendable () -> Void,
        onPause: @escaping @MainActor @Sendable () -> Void,
        onNext: @escaping @MainActor @Sendable () -> Void,
        onPrevious: @escaping @MainActor @Sendable () -> Void
    ) {
        removeRemoteCommandTargets()

        let center = MPRemoteCommandCenter.shared()

        remoteCommandTargets = [
            (
                command: center.playCommand,
                token: center.playCommand.addTarget { _ in
                    onPlay()
                    return .success
                }
            ),
            (
                command: center.pauseCommand,
                token: center.pauseCommand.addTarget { _ in
                    onPause()
                    return .success
                }
            ),
            (
                command: center.nextTrackCommand,
                token: center.nextTrackCommand.addTarget { _ in
                    onNext()
                    return .success
                }
            ),
            (
                command: center.previousTrackCommand,
                token: center.previousTrackCommand.addTarget { _ in
                    onPrevious()
                    return .success
                }
            ),
            (
                command: center.changePlaybackPositionCommand,
                token: center.changePlaybackPositionCommand.addTarget { [weak self] event in
                    guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                        return .commandFailed
                    }

                    // Remote Command Center требует синхронный status, а фактический UI-bound seek переносится на MainActor.
                    Task { @MainActor [weak self] in
                        self?.seek(to: event.positionTime)
                    }

                    return .success
                }
            )
        ]
    }

    /// Настраивает системную команду «Избранное», не затрагивая targets других владельцев.
    func configureFavoriteCommand(
        handler: @escaping @MainActor @Sendable (Bool) -> MPRemoteCommandHandlerStatus
    ) {
        removeFavoriteCommandHandler()

        let command = MPRemoteCommandCenter.shared().likeCommand
        command.localizedTitle = String(localized: "tracklist.favorites.title")
        command.localizedShortTitle = String(localized: "tracklist.favorites.title")
        favoriteCommandTarget = command.addTarget { event in
            guard
                let feedbackEvent = event as? MPFeedbackCommandEvent
            else {
                return .commandFailed
            }

            // MPFeedbackCommandEvent передаёт отрицательное действие для отмены ранее активированной обратной связи.
            return PlayerManager.handleFavoriteCommand(
                isFavorite: feedbackEvent.isNegative == false,
                handler: handler
            )
        }
    }

    /// Синхронизирует системный индикатор с подтверждённым состоянием текущего трека.
    func updateFavoriteCommand(
        isEnabled: Bool,
        isActive: Bool
    ) {
        let command = MPRemoteCommandCenter.shared().likeCommand
        command.isEnabled = isEnabled
        command.isActive = isEnabled && isActive
    }

    /// Удаляет target только этой команды и возвращает системный элемент в отключённое неактивное состояние.
    func removeFavoriteCommandHandler() {
        let command = MPRemoteCommandCenter.shared().likeCommand

        if let favoriteCommandTarget {
            command.removeTarget(favoriteCommandTarget)
            self.favoriteCommandTarget = nil
        }

        command.isEnabled = false
        command.isActive = false
    }

    /// Выполняет доменное действие на MainActor, сохраняя синхронный статус, который требует Remote Command Center.
    nonisolated private static func handleFavoriteCommand(
        isFavorite: Bool,
        handler: @escaping @MainActor @Sendable (Bool) -> MPRemoteCommandHandlerStatus
    ) -> MPRemoteCommandHandlerStatus {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                handler(isFavorite)
            }
        }

        return DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                handler(isFavorite)
            }
        }
    }

    /// Удаляет только target-ы, добавленные этим экземпляром, перед повторной настройкой или освобождением.
    private func removeRemoteCommandTargets() {
        for target in remoteCommandTargets {
            target.command.removeTarget(target.token)
        }

        remoteCommandTargets.removeAll()
    }

    /// Временно выключает системные команды перехода, пока ViewModel не получила достоверный playback-контекст.
    func setTrackNavigationCommandsEnabled(
        isNextEnabled: Bool,
        isPreviousEnabled: Bool
    ) {
        let center = MPRemoteCommandCenter.shared()
        center.nextTrackCommand.isEnabled = isNextEnabled
        center.previousTrackCommand.isEnabled = isPreviousEnabled
    }

    // MARK: - Данные Now Playing

    /// Применяет полный snapshot в Control Center.
    /// PlayerManager НЕ решает, какие данные показывать — он только применяет.
    func applyNowPlaying(snapshot: NowPlayingSnapshot) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: snapshot.title,
            MPMediaItemPropertyArtist: snapshot.artist,
            MPMediaItemPropertyPlaybackDuration: snapshot.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: snapshot.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: snapshot.isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]

        if let album = snapshot.album,
           album.isEmpty == false {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        
        if let artwork = snapshot.artwork,
           artwork.width > 0,
           artwork.height > 0 {
            info[MPMediaItemPropertyArtwork] = Self.makeNowPlayingArtwork(from: artwork)
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Формирует callback обложки без наследования MainActor.
    /// MediaPlayer запрашивает изображение на собственной очереди, поэтому callback
    /// захватывает только неизменяемый CGImage и не обращается к состоянию PlayerManager.
    nonisolated private static func makeNowPlayingArtwork(from artwork: CGImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: CGSize(width: artwork.width, height: artwork.height)) { _ in
            UIImage(cgImage: artwork)
        }
    }
    
    /// Обновляет только время и playbackRate, не трогая остальную карточку.
    func applyPlaybackTime(currentTime: TimeInterval, isPlaying: Bool) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
