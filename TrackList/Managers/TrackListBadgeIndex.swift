//
//  TrackListBadgeIndex.swift
//  TrackList
//
//  Индекс бейджей треклистов.
//
//  Роль:
//  - хранит быстрый доступ к семантическим принадлежностям треклистов по trackId;
//  - централизует расчёт membership-бейджей;
//  - убирает повторный обход треклистов из provider;
//  - изменяет только связи затронутого треклиста или trackId.
//
//  Created by Pavel Fomin on 15.05.2026.
//

import Foundation

/// Описывает уже сохранённое изменение, которое индекс применяет без обхода всех треклистов.
enum TrackListBadgeIndexChange {
    /// Полностью задаёт связи нового или восстановленного треклиста.
    case trackListRelationsReplaced(TrackList)
    /// Изменяет принадлежность только добавленных и удалённых логических идентификаторов.
    case trackIdsChanged(
        trackListId: UUID,
        membership: TrackListMembership,
        addedTrackIds: Set<UUID>,
        removedTrackIds: Set<UUID>
    )
    /// Обновляет отображаемое имя или назначение только у уже связанных с треклистом trackId.
    case trackListMetadataChanged(TrackListMeta)
    /// Удаляет из индекса все связи удалённого треклиста через обратный индекс.
    case trackListDeleted(UUID)
    /// Перечитывает только восстановленный треклист, когда его состава нет в payload операции.
    case trackListRelationsReloadRequested(UUID)
}

@MainActor
final class TrackListBadgeIndex {

    static let shared = TrackListBadgeIndex()

    // MARK: - Состояние

    /// Хранит связи по trackId и по идентификатору треклиста, чтобы одинаковые названия не скрывали разные записи.
    private var membershipsByTrackId: [UUID: [UUID: TrackListMembership]] = [:]
    /// Позволяет удалить или переименовать связи одного треклиста без обхода всех trackId.
    private var trackIdsByTrackListId: [UUID: Set<UUID>] = [:]
    private var observers: [NSObjectProtocol] = []
    private let trackListsManager: TrackListsManager
    private let trackListManager: TrackListManager

    // MARK: - Инициализация

    /// Создаёт индекс с явными зависимостями, чтобы поиск использовал тот же источник треклистов, что и фонотека.
    init(
        trackListsManager: TrackListsManager = .shared,
        trackListManager: TrackListManager = .shared,
        observesTrackListChanges: Bool = true
    ) {
        self.trackListsManager = trackListsManager
        self.trackListManager = trackListManager
        buildInitialIndex()
        if observesTrackListChanges {
            observeTrackListChanges()
        }
    }

    isolated deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Публичное

    func badges(for trackIds: [UUID]) -> [UUID: [TrackListMembership]] {
        var result: [UUID: [TrackListMembership]] = [:]

        for trackId in trackIds {
            let memberships = membershipsByTrackId[trackId].map { Array($0.values) } ?? []
            result[trackId] = Set(memberships).sorted {
                $0.storedName.localizedCaseInsensitiveCompare($1.storedName) == .orderedAscending
            }
        }

        return result
    }

    /// Строит стартовый снимок один раз при создании индекса до поступления точечных изменений.
    private func buildInitialIndex() {
        let metas = (try? trackListsManager.loadTrackListMetas()) ?? []

        for meta in metas {
            let tracks = (try? trackListManager.loadTracks(for: meta.id)) ?? []
            replaceRelations(
                for: TrackList(
                    id: meta.id,
                    name: meta.name,
                    createdAt: meta.createdAt,
                    kind: meta.kind,
                    tracks: tracks
                )
            )
        }
    }

    // MARK: - Наблюдение

    private func observeTrackListChanges() {
        let badgeIndexObserver = NotificationCenter.default.addObserver(
            forName: .trackListBadgeIndexDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let change = notification.object as? TrackListBadgeIndexChange else {
                return
            }

            // Все production-издатели этого уведомления изолированы MainActor, поэтому индекс обновляется до уведомления экранов.
            MainActor.assumeIsolated {
                self?.apply(change)
            }
        }

        observers.append(badgeIndexObserver)
    }

    /// Применяет уже сохранённую мутацию, затрагивая только переданные связи.
    private func apply(_ change: TrackListBadgeIndexChange) {
        switch change {
        case let .trackListRelationsReplaced(trackList):
            replaceRelations(for: trackList)
        case let .trackIdsChanged(trackListId, membership, addedTrackIds, removedTrackIds):
            for trackId in removedTrackIds {
                removeMembership(trackListId: trackListId, trackId: trackId)
            }
            for trackId in addedTrackIds {
                insertMembership(
                    membership,
                    trackListId: trackListId,
                    trackId: trackId
                )
            }
        case let .trackListMetadataChanged(meta):
            updateMembership(for: meta)
        case let .trackListDeleted(trackListId):
            removeRelations(for: trackListId)
        case let .trackListRelationsReloadRequested(trackListId):
            reloadRelations(for: trackListId)
        }
    }

    /// Заменяет только связи одного треклиста, например после его создания или восстановления.
    private func replaceRelations(for trackList: TrackList) {
        let membership = TrackListMembership(
            storedName: trackList.name,
            kind: trackList.kind
        )
        let updatedTrackIds = Set(trackList.tracks.map(\.trackId))
        let previousTrackIds = trackIdsByTrackListId[trackList.id] ?? []

        for trackId in previousTrackIds.subtracting(updatedTrackIds) {
            removeMembership(trackListId: trackList.id, trackId: trackId)
        }
        for trackId in updatedTrackIds {
            insertMembership(
                membership,
                trackListId: trackList.id,
                trackId: trackId
            )
        }
    }

    /// Вставляет связь одного логического трека и актуализирует обратный индекс треклиста.
    private func insertMembership(
        _ membership: TrackListMembership,
        trackListId: UUID,
        trackId: UUID
    ) {
        membershipsByTrackId[trackId, default: [:]][trackListId] = membership
        trackIdsByTrackListId[trackListId, default: []].insert(trackId)
    }

    /// Удаляет связь одного логического трека, сохраняя остальные треклисты этого trackId.
    private func removeMembership(trackListId: UUID, trackId: UUID) {
        if var memberships = membershipsByTrackId[trackId] {
            memberships.removeValue(forKey: trackListId)
            if memberships.isEmpty {
                membershipsByTrackId.removeValue(forKey: trackId)
            } else {
                membershipsByTrackId[trackId] = memberships
            }
        }

        if var trackIds = trackIdsByTrackListId[trackListId] {
            trackIds.remove(trackId)
            if trackIds.isEmpty {
                trackIdsByTrackListId.removeValue(forKey: trackListId)
            } else {
                trackIdsByTrackListId[trackListId] = trackIds
            }
        }
    }

    /// Обновляет presentation-свойства только у связей одного треклиста после изменения его метаданных.
    private func updateMembership(for meta: TrackListMeta) {
        let membership = TrackListMembership(
            storedName: meta.name,
            kind: meta.kind
        )

        for trackId in trackIdsByTrackListId[meta.id] ?? [] {
            membershipsByTrackId[trackId]?[meta.id] = membership
        }
    }

    /// Удаляет связанные trackId через обратный индекс, не просматривая остальное содержимое индекса.
    private func removeRelations(for trackListId: UUID) {
        for trackId in trackIdsByTrackListId[trackListId] ?? [] {
            guard var memberships = membershipsByTrackId[trackId] else {
                continue
            }

            memberships.removeValue(forKey: trackListId)
            if memberships.isEmpty {
                membershipsByTrackId.removeValue(forKey: trackId)
            } else {
                membershipsByTrackId[trackId] = memberships
            }
        }

        trackIdsByTrackListId.removeValue(forKey: trackListId)
    }

    /// Перечитывает один восстановленный треклист, когда SQLite-операция не передаёт его состав в событии.
    private func reloadRelations(for trackListId: UUID) {
        guard let trackList = try? trackListManager.getTrackListById(trackListId) else {
            return
        }

        replaceRelations(for: trackList)
    }
}
