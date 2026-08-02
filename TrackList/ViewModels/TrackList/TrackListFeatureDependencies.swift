//
//  TrackListFeatureDependencies.swift
//  TrackList
//
//  Подготовленные фабрики detail-flow одного треклиста.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import Foundation

/// Передаёт detail-экрану только его готовые production-фабрики.
/// Тип не является контейнером сервисов и не выполняет операции.
@MainActor
struct TrackListFeatureDependencies {

    /// Создаёт ViewModel detail-экрана с уже определёнными зависимостями.
    let viewModelFactory: TrackListViewModelFactory
    /// Создаёт обработчик действий detail-flow с уже определёнными зависимостями.
    let actionHandlerFactory: TrackListFlowActionHandlerFactory
}
