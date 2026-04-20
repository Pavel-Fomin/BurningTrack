//
//  ArtworkWriteAction.swift
//  TrackList
//
//  Итоговое действие записи обложки в файл.
//
//  Роль:
//  - не хранит состояние UI,
//  - не знает, что происходило в форме,
//  - описывает только конечную файловую операцию.
//
//  Использование:
//  - вычисляется перед сохранением,
//  - передаётся в writer-слой.
//
//  Created by Pavel Fomin on 19.04.2026.
//

import Foundation

enum ArtworkWriteAction: Equatable {

    /// Обложку не трогаем.
    case none

    /// Удаляем текущую обложку из файла.
    case remove

    /// Заменяем текущую обложку новой.
    case replace(data: Data)
}
