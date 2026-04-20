//
//  ArtworkEditState.swift
//  TrackList
//
//  Состояние редактирования обложки в форме.
//
//  Роль:
//  - хранит только локальное состояние UI,
//  - не пишет ничего в файл,
//  - не зависит от TagLib,
//  - в момент сохранения переводится в ArtworkWriteAction.
//
//  Логика:
//  - если исходная обложка была и пользователь ничего не менял,
//    действие записи = .none
//  - если исходная обложка была и пользователь удалил её,
//    действие записи = .remove
//  - если пользователь выбрал новую обложку,
//    действие записи = .replace(data:)
//  - если исходной обложки не было и пользователь ничего не выбрал,
//    действие записи = .none
//
//  Created by Pavel Fomin on 19.04.2026.
//

import Foundation

struct ArtworkEditState: Equatable {

    // MARK: - Stored state

    /// Была ли обложка у трека в момент открытия экрана.
    let hadOriginalArtwork: Bool

    /// Новая обложка, выбранная пользователем в форме.
    private(set) var newArtworkData: Data?

    /// Флаг локального удаления обложки в форме.
    private(set) var isMarkedForRemoval: Bool

    // MARK: - Init

    init(hadOriginalArtwork: Bool) {
        self.hadOriginalArtwork = hadOriginalArtwork
        self.newArtworkData = nil
        self.isMarkedForRemoval = false
    }

    // MARK: - Derived state

    /// Нужно ли сейчас показывать обложку в превью формы.
    var hasArtworkForPreview: Bool {
        if newArtworkData != nil {return true}
        if isMarkedForRemoval {return false}
        return hadOriginalArtwork
    }

    /// Нужно ли показывать кнопку "Добавить".
    var shouldShowAddButton: Bool {
        hasArtworkForPreview == false
    }

    /// Нужно ли показывать кнопку "Удалить".
    var shouldShowRemoveButton: Bool {
        hasArtworkForPreview == true
    }

    /// Были ли изменения по обложке относительно исходного состояния.
    var isChanged: Bool {
        makeWriteAction() != .none
    }

    // MARK: - Mutating

    /// Пользователь выбрал новую обложку.
    /// С этого момента она становится текущим локальным превью.
    mutating func setNewArtwork(data: Data) {
        newArtworkData = data
        isMarkedForRemoval = false
    }

    /// Пользователь удалил обложку в форме.
    /// Удаление пока только локальное, до нажатия "Сохранить".
    mutating func removeArtwork() {
        newArtworkData = nil
        isMarkedForRemoval = true
    }

    /// Сброс локальных изменений по обложке.
    /// Возвращает форму к исходному состоянию.
    mutating func reset() {
        newArtworkData = nil
        isMarkedForRemoval = false
    }

    // MARK: - Mapping

    /// Переводит состояние формы в итоговую команду записи.
    func makeWriteAction() -> ArtworkWriteAction {
        if let newArtworkData {return .replace(data: newArtworkData)}
        if hadOriginalArtwork && isMarkedForRemoval {return .remove}
        return .none
    }
}
