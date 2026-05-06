# Toast Architecture

## 1. Назначение системы

Toast используется для короткой пользовательской обратной связи после действий в приложении: успешное добавление трека, сохранение или изменение треклиста, ошибки загрузки/сохранения, предупреждения о недоступных данных.

Система решает три задачи:

- отделяет пользовательское событие от SwiftUI-отрисовки;
- централизует тексты, стиль и защиту от дублей;
- дает единый вход для ошибок пользовательского уровня через `AppError`.

`ToastManager` используется как централизованный singleton, потому что Toast является глобальным overlay-состоянием приложения. UI подключается один раз через `toastHost()`, а вызывающий код не управляет размещением, анимацией и временем скрытия Toast.

## 2. Архитектурная схема

Основная цепочка:

```text
User Action
-> AppError / ToastEvent
-> ToastManager
-> ToastData
-> ToastHostModifier
-> ToastView
```

`ToastEvent` создается в местах, где уже известен результат пользовательского действия и есть данные для пользовательского сообщения:

- в `ViewModel` / `Container` для flow, которым они владеют напрямую;
- в `AppCommandExecutor` для command-flow, где команда сама завершает сценарий и показывает success Toast;
- в `TrackToastEventBuilder`, когда для track-style Toast нужно подготовить snapshot/artwork вне UI-контейнера.

`AppError` создается в manager-слое и командном слое при ошибках пользовательского уровня. Для треклистов текущий manager-слой бросает `AppError.trackListLoadFailed`, `AppError.trackListSaveFailed`, `AppError.trackListNotFound`, `AppError.trackListNameInvalid`.

Преобразование `AppError` в `ToastEvent` выполняется только в `AppError+ToastEvent.swift` через `AppError.toastEvent`. `ToastManager.handle(_ error: AppError)` использует этот mapping и дальше обрабатывает ошибку так же, как обычный `ToastEvent`.

За UI отвечают только:

- `ToastHostModifier` - подписка на `ToastManager.shared.data`, overlay, позиция, transition;
- `ToastView` - визуальное представление `ToastData`.

## 3. Основные файлы

### ToastManager.swift

Зона ответственности: глобальное состояние текущего Toast, преобразование `ToastEvent` в `ToastData`, suppress дублей, запуск task скрытия.

Может делать:

- принимать `ToastEvent`;
- принимать `AppError` через `handle(_ error: AppError)`;
- формировать `ToastData`;
- отменять предыдущий dismiss task после проверки дубля;
- очищать `data` после `duration`.

Не должен делать:

- выполнять бизнес-операции;
- читать или сохранять треклисты;
- знать про `TrackListManager` / `TrackListsManager`;
- собирать runtime snapshot;
- читать файлы треков или artwork metadata.

### ToastEvent.swift

Зона ответственности: декларативный список событий, которые могут быть представлены как Toast.

Может делать:

- хранить cases success/warning/error;
- передавать уже подготовленные `title`, `artist`, `artwork`, `trackListName`, `message`.

Не должен делать:

- показывать Toast;
- превращаться в `ToastData`;
- читать файлы;
- обращаться к runtime metadata;
- строить artwork.

### ToastData.swift

Зона ответственности: готовая модель для `ToastView`.

Может делать:

- хранить `style`, `artworkImage`, `message`;
- определять equality для suppress дублей по `style` и `message`.

Не должен делать:

- знать источник события;
- обращаться к managers;
- декодировать artwork;
- содержать бизнес-логику.

### ToastView.swift

Зона ответственности: отрисовка одного Toast по `ToastData`.

Может делать:

- показывать track-style layout с artwork/title/artist;
- показывать message-only layout без artwork;
- применять SwiftUI styling.

Не должен делать:

- вызывать `ToastManager`;
- создавать `ToastEvent`;
- читать snapshot/artwork data;
- принимать решения об ошибках или бизнес-сценариях.

### ToastHostModifier.swift

Зона ответственности: единый UI-host для Toast overlay.

Может делать:

- наблюдать `ToastManager.shared`;
- размещать `ToastView` поверх текущего UI;
- задавать transition, animation, z-index и top safe-area offset;
- подключаться через `View.toastHost()`.

Не должен делать:

- создавать Toast-события;
- обрабатывать ошибки;
- выполнять бизнес-команды;
- читать данные треклистов или фонотеки.

### AppError.swift

Зона ответственности: единый enum ошибок пользовательского уровня.

Может делать:

- описывать ошибки файлов, bookmark, фонотеки, треков, треклистов, плеера, импорта, экспорта, playback, metadata, tag writing и навигации;
- использоваться как `Error` в throwing API.

Не должен делать:

- показывать Toast;
- `AppError.swift` не содержит UI-тексты. Пользовательские тексты живут в `AppError+ToastEvent.swift` и `ToastManager.swift`;
- знать о `ToastManager`;
- выполнять fallback-логику.

### AppError+ToastEvent.swift

Зона ответственности: централизованный mapping `AppError -> ToastEvent`.

Может делать:

- переводить каждую ошибку в пользовательское Toast-событие;
- хранить тексты fallback-сообщений для ошибок.

Не должен делать:

- показывать Toast;
- читать состояние приложения;
- обращаться к managers;
- содержать бизнес-логику.

### TrackToastEventBuilder.swift

Зона ответственности: подготовка track-style `ToastEvent` для сценариев, где нужны `title`, `artist` и `.toast` artwork.

Может делать:

- читать `TrackRuntimeStore`;
- строить snapshot через `TrackRuntimeSnapshotBuilder`;
- получать изображение через `ArtworkProvider.shared.image(..., purpose: .toast)`;
- возвращать готовый `ToastEvent`.

Не должен делать:

- показывать Toast;
- менять треклисты;
- вызывать `ToastManager`;
- закрывать sheet;
- содержать бизнес-логику добавления/удаления.

## 4. Правила архитектуры

### ToastManager

- `ToastManager` только показывает Toast и управляет жизненным циклом текущего `ToastData`.
- `ToastManager` не содержит бизнес-логики.
- `ToastManager` не знает про `TrackListManager` и `TrackListsManager`.
- Duplicate guard выполняется до `dismissTask.cancel()`.
- Identical Toast не должен перезапускать таймер скрытия.

### AppError

- `AppError` является единым источником ошибок пользовательского уровня.
- Manager-слой должен бросать `AppError` для ошибок, которые должны быть показаны пользователю.
- `AppError` не показывает Toast сам.
- Mapping в пользовательское сообщение выполняется в `AppError+ToastEvent.swift`.

### ToastEvent

- `ToastEvent` является декларативным UI-событием.
- События разделены по смыслу на success, warning и error cases.
- `ToastEvent` хранит только готовые данные события.
- `ToastEvent` не должен читать файлы или runtime metadata.

### Builders

- `TrackToastEventBuilder` готовит данные для Toast.
- Builder не показывает Toast.
- Builder может читать snapshot и artwork.
- UI-контейнеры не должны напрямую собирать artwork/runtime snapshot для track-style Toast.

### Managers

- `TrackListManager` и `TrackListsManager` не показывают Toast.
- Manager-слой только бросает ошибки или возвращает результат операции.
- В managers запрещен `ToastManager.shared.handle(...)`.

### ViewModel / Container

- Пользовательские действия ловят `AppError`.
- `ViewModel` / `Container` показывают error Toast через `ToastManager.shared.handle(appError)`.
- Generic fallback должен идти отдельным `catch` после `catch let appError as AppError`.
- Success Toast показывается только после успешного `try`.
- В текущем command-flow `AppCommandExecutor` также создает и показывает success Toast после успешного выполнения команды; контейнеры вокруг него отвечают за обработку thrown errors.

## 5. Правила обработки ошибок

Для пользовательских действий используется AppError-aware catch:

```swift
catch let appError as AppError {
    ToastManager.shared.handle(appError)
} catch {
    ToastManager.shared.handle(AppError.trackListSaveFailed)
}
```

Правила:

- `catch let appError as AppError` должен идти до generic `catch`.
- Generic fallback допустим только с конкретным `AppError`, соответствующим операции: load -> `trackListLoadFailed`, save/delete/rename -> `trackListSaveFailed`.
- Silent fail запрещен в пользовательских сценариях, потому что пользователь не получает подтверждение, что операция не была выполнена.
- `fatalError` запрещен для пользовательских сценариев, потому что ошибка пользователя или файловой системы не должна завершать приложение.

`try?` допустим там, где данные являются вспомогательными и отсутствие результата не является пользовательской ошибкой текущего действия:

- best-effort чтение badge-данных в `DefaultTrackListBadgeProvider`;
- internal fallback `loadTrackListMetasOrEmpty()`;
- debug/diagnostic вывод в `printTrackLists()`;
- технические операции очистки или задержки, где ошибка не влияет на user-facing flow.

`try?` запрещен в пользовательском действии, если операция является самим действием пользователя и при ошибке нужен Toast. В таких местах должен быть `do/catch` с `AppError` branch и generic fallback.

## 6. Track-style Toast

Track-style Toast показывает:

- artwork;
- artist;
- title;
- короткое сообщение справа.

Текущие track-style сценарии:

- `trackAddedToPlayer`;
- `trackAddedToTrackList`.

`trackAddedToPlayer` сейчас создается в `AppCommandExecutor.addTrackToPlayer(trackId:)` после успешного добавления трека в `PlaylistManager`.

`trackAddedToTrackList` создается:

- в `AppCommandExecutor.addTrackToTrackList(trackId:trackListId:)` для добавления одного трека через command-flow;
- через `TrackToastEventBuilder.trackAddedToTrackList(track:trackListName:)` в `NewTrackListSelectionContainer`, когда выбран ровно один трек.

`TrackToastEventBuilder` существует, чтобы контейнер не собирал runtime snapshot и artwork сам. Контейнер должен знать, что нужно показать Toast по результату действия, но не должен знать, как достать `.toast` artwork из `TrackRuntimeStore`, `TrackRuntimeSnapshotBuilder` и `ArtworkProvider`.

## 7. Duplicate Toast Handling

Duplicate suppression выполняется в `ToastManager.show(_:duration:)`.

`ToastData` считается одинаковым, если совпадают:

- `style`;
- `message`.

`id` и `artworkImage` не участвуют в equality. Это позволяет не пересоздавать визуально тот же Toast и не сбрасывать его timer при повторном identical event.

Порядок важен:

```swift
if data == newToast {
    return
}

dismissTask?.cancel()
```

`dismissTask` нельзя cancel до duplicate check. Если сначала отменить task, а потом выйти на duplicate, текущий Toast останется без активного scheduled dismiss.

## 8. Текущие throws-контракты

Актуальные throwing methods в tracklist storage scope:

- `TrackListManager.getTrackListById(_:) throws -> TrackList`
- `TrackListManager.loadTracks(for:) throws -> [Track]`
- `TrackListManager.deleteTracksFile(for:) throws`
- `TrackListsManager.loadTrackListMetas() throws -> [TrackListMeta]`
- `TrackListsManager.deleteTrackList(id:) throws`
- `TrackListsManager.renameTrackList(id:to:) throws`
- `TrackListsManager.saveTrackListMetas(_:) throws`
- `TrackListsManager.saveTrackListMeta(_:) throws`
- `TrackListsManager.saveTrackLists(_:) throws`

Эти методы переведены на `throws`, потому что их ошибки являются user-facing для треклистов:

- невозможность получить documents/metas URL;
- ошибка чтения или декодирования JSON;
- ошибка записи `tracklists.json`;
- ошибка удаления `tracklist_<id>.json`;
- отсутствие треклиста по id;
- невалидное имя треклиста;
- невозможность сохранить tracks/metas после мутации.

Throwing contract нужен, чтобы manager-слой не делал silent return, а вызывающий `ViewModel` / `Container` мог показать `AppError` через Toast.

## 9. Что считается нарушением архитектуры

- Toast внутри manager.
- `ToastManager.shared.handle(...)` внутри `TrackListManager` или `TrackListsManager`.
- Silent `return` вместо `throw` в user-facing ошибке.
- `fatalError` в пользовательском flow.
- Generic `catch` без предварительного `catch let appError as AppError`.
- `try?` в пользовательском действии.
- Success Toast до successful `try`.
- Сбор artwork/runtime metadata внутри UI-контейнера.
- Чтение файлов или runtime metadata внутри `ToastEvent`.
- Показ Toast из `AppError` или `AppError+ToastEvent`.
- Бизнес-логика внутри `ToastManager`, `ToastView` или `ToastHostModifier`.

## 10. Остаточные технические долги

- Orphan tracklist file при create: `createTrackListInternal` сначала сохраняет `tracklist_<id>.json`, затем пишет meta в `tracklists.json`; если meta save падает, файл треков уже создан.
- Meta/file atomicity: операции с файлом треков и `tracklists.json` не являются единой атомарной транзакцией.
- `saveTrackLists` bulk-save behavior: `saveTrackLists` остаётся техническим долгом: ошибка сохранения отдельного tracks-файла учитывается через `didSaveTracks`, но контракт bulk-save требует отдельного аудита перед активным использованием.
