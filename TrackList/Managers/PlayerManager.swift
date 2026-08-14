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
import MediaPlayer
@preconcurrency import AVFoundation

/// Общий интервал обновления пользовательского progress без отдельного визуального таймера.
enum PlayerProgressObservationConfiguration {

    /// Четыре обновления в секунду делают waveform плавной, не приближаясь к кадровой частоте интерфейса.
    static let interval: TimeInterval = 0.25
}

final class PlayerManager {

    // MARK: - Приватное

    private let player = AVPlayer()
    private var timeObserverToken: Any?
    private var currentAccessedURL: URL?
    /// URL сохраняется после успешной подготовки AVPlayerItem и используется только связанными runtime-сценариями.
    private var currentPreparedURL: URL?
    /// Target-ы системных playback-команд, принадлежащие этому экземпляру PlayerManager.
    private var remoteCommandTargets: [(command: MPRemoteCommand, token: Any)] = []
    /// Target системной команды «Избранное», который удаляется отдельно при повторной настройке.
    private var favoriteCommandTarget: Any?

    // MARK: - Состояние трека

    /// ID текущего трека, загруженного в плеер (не обязательно играет).
    private(set) var currentTrackId: UUID?

    /// Флаг, что плеер сейчас воспроизводит трек.
    private(set) var isPlaying: Bool = false

    // MARK: - Инициализация

    init() {
        print("🧠 PlayerManager инициализирован")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(trackDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        removeTimeObserver()
        removeRemoteCommandTargets()
        removeFavoriteCommandHandler()
    }

    // MARK: - Уведомление о завершении

    @objc private func trackDidFinishPlaying() {
        // Трек доиграл до конца — считаем, что больше не играет
        isPlaying = false
        NotificationCenter.default.post(name: .trackDidFinish, object: nil)
    }

    // MARK: - Основное воспроизведение

    func play(
        track: any TrackDisplayable,
        onPreparedLocalFile: @escaping PlayerPreparedLocalFileHandler
    ) async throws {
        let trackId = track.trackId

        // 1. Получаем URL воспроизведения из подходящего источника.
        let playbackResource = try await playbackResource(for: track)
        let resolvedURL = playbackResource.url

        // 2. Активация аудиосессии
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            PersistentLogger.log("❌ PlayerManager: audio session failed error=\(error)")
            throw AppError.audioSessionFailed
        }

        // 3. Закрываем старый доступ
        stopAccessingCurrentTrack()

        // 4. Пытаемся открыть security-scoped доступ только для файлов прикреплённых папок.
        if playbackResource.needsSecurityScopedAccess {
            // В iOS 26 (File Provider Storage) startAccessing на файл может вернуть false,
            // при этом доступ может быть получен через root-scope папки.
            let started = resolvedURL.startAccessingSecurityScopedResource()
            if started {
                currentAccessedURL = resolvedURL
            } else {
                currentAccessedURL = nil
                print("⚠️ startAccessing вернул false для файла, пробуем играть через root-scope:", resolvedURL.lastPathComponent)
                PersistentLogger.log("⚠️ PlayerManager: startAccessing false file=\(resolvedURL.lastPathComponent)")
            }
        } else {
            currentAccessedURL = nil
        }

        // 5. Создаём AVPlayerItem
        let item = AVPlayerItem(url: resolvedURL)
        do {
            _ = try await item.asset.load(.isPlayable)
        } catch {
            PersistentLogger.log("❌ PlayerManager: not playable error=\(error)")
            throw AppError.fileNotPlayable
        }

        // 6. Подключаем item и играем
        player.replaceCurrentItem(with: item)
        player.play()
        PersistentLogger.log("▶️ PlayerManager: play started track=\(resolvedURL.lastPathComponent)")

        // Обновляем состояние текущего трека
        currentTrackId = trackId
        currentPreparedURL = resolvedURL
        isPlaying = true

        if let preparedLocalFileURL = preparedLocalFileURL(for: trackId) {
            // Контрольная точка появляется после подготовки AVPlayerItem и security scope, но до ожидания duration.
            // Менеджер сообщает только ресурс: запуск waveform остаётся ответственностью ViewModel.
            await onPreparedLocalFile(
                PlayerPreparedLocalFile(
                    trackId: trackId,
                    fileURL: preparedLocalFileURL
                )
            )
        }

        // 7. Читаем длительность трека
        let duration = (try? await item.asset.load(.duration))?.seconds ?? 0
        await MainActor.run {
            NotificationCenter.default.post(
                name: .trackDurationUpdated,
                object: nil,
                userInfo: ["duration": duration]
            )
        }
    }

    /// Возвращает URL для AVPlayer и признак необходимости security-scoped доступа.
    private func playbackResource(
        for track: any TrackDisplayable
    ) async throws -> (url: URL, needsSecurityScopedAccess: Bool) {
        if let purchasedTrack = track as? PurchasedITunesPlayableTrack {
            // Трек iTunes приходит из MediaPlayer с готовым assetURL, поэтому BookmarkResolver здесь не нужен.
            return (purchasedTrack.assetURL, false)
        }

        guard let resolvedURL = await BookmarkResolver.url(forTrack: track.trackId) else {
            PersistentLogger.log("❌ PlayerManager: no URL for trackId=\(track.trackId)")
            throw AppError.bookmarkResolveFailed
        }

        return (resolvedURL, true)
    }

    // MARK: - Доступ безопасности

    func stopAccessingCurrentTrack() {
        if let url = currentAccessedURL {
            url.stopAccessingSecurityScopedResource()
            currentAccessedURL = nil
        }

        // После освобождения scope URL закрытого доступа нельзя передавать фоновым производным операциям.
        currentPreparedURL = nil
    }

    /// Отсоединяет текущий AVPlayerItem до записи в файл и освобождает связанный security-scoped доступ.
    /// ViewModel сохраняет display-состояние трека и при следующем запуске создаст новый item по актуальному файлу.
    func releaseCurrentTrackForFileOperation() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        removeTimeObserver()
        stopAccessingCurrentTrack()
        currentTrackId = nil
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
        guard player.currentItem != nil else { return }

        player.seek(
            to: .zero,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] _ in
            self?.player.play()
        }
        isPlaying = true
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

    func observeProgress(update: @escaping (TimeInterval) -> Void) {
        removeTimeObserver()
        let interval = CMTimeMakeWithSeconds(
            PlayerProgressObservationConfiguration.interval,
            preferredTimescale: 600
        )

        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { time in
            update(time.seconds)
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
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void
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
                    guard
                        let self,
                        let event = event as? MPChangePlaybackPositionCommandEvent
                    else { return .commandFailed }

                    self.seek(to: event.positionTime)

                    return .success
                }
            )
        ]
    }

    /// Настраивает системную команду «Избранное», не затрагивая targets других владельцев.
    func configureFavoriteCommand(
        handler: @escaping @MainActor (Bool) -> MPRemoteCommandHandlerStatus
    ) {
        removeFavoriteCommandHandler()

        let command = MPRemoteCommandCenter.shared().likeCommand
        command.localizedTitle = String(localized: "tracklist.favorites.title")
        command.localizedShortTitle = String(localized: "tracklist.favorites.title")
        favoriteCommandTarget = command.addTarget { [weak self] event in
            guard
                let self,
                let feedbackEvent = event as? MPFeedbackCommandEvent
            else {
                return .commandFailed
            }

            // MPFeedbackCommandEvent передаёт отрицательное действие для отмены ранее активированной обратной связи.
            return self.handleFavoriteCommand(
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
    private func handleFavoriteCommand(
        isFavorite: Bool,
        handler: @escaping @MainActor (Bool) -> MPRemoteCommandHandlerStatus
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
            info[MPMediaItemPropertyArtwork] =
                MPMediaItemArtwork(boundsSize: CGSize(width: artwork.width, height: artwork.height)) { _ in
                    UIImage(cgImage: artwork)
                }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    /// Обновляет только время и playbackRate, не трогая остальную карточку.
    func applyPlaybackTime(currentTime: TimeInterval, isPlaying: Bool) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
