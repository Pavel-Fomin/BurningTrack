# TrackList — проектные инструкции

## Границы задачи и Git

- Рабочая ветка проекта всегда `main`.
- Перед изменением проверяй `git fetch`, `git status --short --branch` и расхождение `main...origin/main`. При расхождении остановись и сообщи результат.
- Незакоммиченные изменения относятся к одной общей задаче из разных чатов. Сохраняй их: не выполняй `reset`, `checkout`, `stash` или очистку worktree.
- Не меняй файлы, тесты, project settings, локализацию, persistence или архитектуру за пределами явно согласованного scope.
- Если запрос является аудитом, диагностикой или содержит запрет на изменения, верни только доказательный отчёт. План или дизайн не является разрешением на реализацию.

## Экранная архитектура

- Обязательный production-flow: `View → typed Action → ActionHandler → Domain / Manager → Presenter → ScreenState → View`.
- Не заменяй этот flow на MV, MVI, Redux, TCA, Coordinator, service locator или другую архитектуру без явного решения пользователя.
- `View` отображает готовый `ScreenState` и отправляет typed actions. В ней нет бизнес-логики, SQL, прямого доступа к Manager/singleton или скрытого разрешения production-зависимостей.
- `ActionHandler` принимает пользовательское намерение, вызывает Domain/Manager и передаёт presentation-результат в установленный feature flow. `Presenter` собирает UI-данные и `ScreenState`; не переносить эту работу в `View` или универсальную ViewModel.
- Не дублируй `ScreenState` параллельным локальным View-state. `@State`, `@Binding`, `@FocusState` и `@GestureState` допустимы только для действительно локального, transient UI-состояния.

## Feature composition и зависимости

- Для feature используй текущий граф: `TrackListApp (Composition Root) → FeatureFactory → Container → ScreenStore / ViewModel / Presenter / ActionHandler → ScreenState → View`.
- `TrackListApp` — единственное место разрешения application-wide production singleton. FeatureFactory получает уже подготовленные зависимости явно.
- Production-зависимости не создаются и не разрешаются самостоятельно внутри `View`, `ViewModel`, `Presenter`, leaf row, `ActionHandler` или UIKit/SwiftUI bridge. Feature-компоненты получают необходимые production-зависимости явно из `FeatureFactory` / `Container` через initializer injection или существующие typed contracts.
- `Container` владеет стабильным `@StateObject` graph одного destination; повторный `body` не должен пересоздавать handler, ViewModel или task owner.
- Используй протоколы для реально заменяемых domain/presentation dependencies и существующие shared typed components, а не source-specific shortcut или новый global singleton.
- Не выполняй неявную миграцию `ObservableObject`/Combine на Observation. Сохраняй текущий owner и actor isolation, пока отдельная задача явно не требует миграцию.

## Навигация, sheets и lifecycle

- Сохраняй существующие typed routes и ownership: `NavigationCoordinator` отвечает за app navigation, `SheetManager` — за единое sheet presentation-state, `SheetHostModifier` — единственный `.sheet(item:)` host.
- `SheetHostModifier` только materializes feature view. Feature-local mutable state, callbacks и domain-операции не принадлежат `SheetManager`.
- View направляет explicit close, cancel и lifecycle events в typed Action/ActionHandler. Не вызывай `dismiss()`, `SheetManager.shared.closeActive()` и не создавай параллельный router в leaf View как замену этого flow.
- Глобальное завершение lifecycle — только `SheetHost.onDismiss → SheetManager.handleDismiss`. Локальный `onDisappear` допустим, если он не инициирует глобальный dismiss.
- Route identity неизменяема. Для асинхронных sheet flows используй `sessionID`/`operationID`, чтобы поздний результат не изменил superseded UI. Закрытие UI не должно автоматически отменять долгоживущую operation, если контракт feature не говорит обратное.

## Concurrency и состояние операций

- Не делай вывод о Swift language mode, strict concurrency или default actor isolation по версии Xcode, SDK или Swift toolchain. Перед изменениями Swift Concurrency проверяй фактические build settings проекта (`SWIFT_VERSION`, concurrency/isolation settings при наличии) и конкретную compiler diagnostic.
- UI-bound state изолируй на `@MainActor`; для перехода между isolation boundaries передавай immutable snapshots или корректные `Sendable` value types.
- Сохраняй ownership и cancellation существующих `Task`. Не добавляй `Task.detached`, `@unchecked Sendable`, `nonisolated(unsafe)`, locks или semaphores без явной необходимости, проверяемого инварианта и согласованного scope.
- Проверяй отмену у долгих операций и не позволяй late async result менять новый route/session.

## Persistence, внешние источники и Live Activity

- Текущий persistence contract — SQLite (`AppDatabase` и protocol-based stores). Не вводи SwiftData, Core Data, `@Query`, `ModelContext` или прямые persistence mutations из View без отдельного решения о миграции.
- Сохраняй source-specific identity и contracts. Purchased iTunes использует стабильный identity и ready `assetURL`; не направляй его через `BookmarkResolver` или SQLite-local track assumptions.
- ActivityKit остаётся infrastructure boundary за `ProgressLiveActivityManaging`; Export и другие feature не должны напрямую владеть `Activity` lifecycle. Сохраняй `operationID` и terminal cleanup.
- Не заменяй существующий Export lifecycle новым BackgroundTasks flow без отдельного решения о lifecycle, cancellation, persistence и presentation.

## Tests и verification

- Текущий unit-test framework — XCTest. Не мигрируй XCTest на Swift Testing и не смешивай test framework без отдельного решения проекта.
- Тестируй контракт на его собственном слое: presentation constants в Presenter, semantic errors в ActionHandler, Toast mapping отдельно. Для cancellation/late-result сценариев используй controlled fake operation.
- Не использовать симуляторы. Runtime/XCTest evidence для TrackList выполняется только на физическом устройстве; build — это только compilation evidence.
- Не меняй signing или project settings ради test run. При необходимости исключай `TrackListUITests` через `-skip-testing:TrackListUITests` и указывай точные `-only-testing` selectors.

## Код и файлы

- Всегда комментируй новый и существенно изменённый код. Комментарии — на русском, без эмодзи. При замене фрагмента сохраняй смысл существующих комментариев.
- Каждый новый Swift-файл создавай с header:

  ```swift
  //
  //  Name.swift
  //  TrackList
  //
  //  Краткое описание.
  //
  //  Created by Pavel Fomin on dd.mm.yyyy.
  //
  ```

- Интерфейс приложения по умолчанию англоязычный; новые пользовательские строки добавляй через `Localizable.xcstrings`, если задача явно не ограничена иным scope.
- Никогда не выполняй commit или push, даже если это прямо запрошено.
