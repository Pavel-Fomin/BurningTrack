// TrackList

Карта архитектуры TrackList

Назначение

Этот документ фиксирует текущую модульную карту проекта TrackList после стабилизации доступа к фонотеке, sync-пайплайна и reboot-сценария.

Цель карты:
    •    быстро понимать, какой модуль за что отвечает;
    •    не смешивать обязанности при доработках;
    •    проще проверять новые решения на архитектурную чистоту;
    •    быстрее находить место для новых фич.

⸻

Короткая схема зависимостей

MusicLibraryManager
 ├─ BookmarkResolver
 ├─ LibrarySyncModule
 ├─ TrackRegistry
 └─ BookmarksRegistry

LibrarySyncModule
 ├─ LibraryScanner
 ├─ TrackIdentityResolver
 ├─ TrackRegistry
 └─ BookmarksRegistry

PlaylistManager
 └─ BookmarkResolver

TrackListViewModel
 ├─ TrackListManager
 ├─ TrackListsManager
 ├─ TrackRuntimeStore
 └─ TrackRuntimeSnapshotBuilder

PlayerViewModel
 ├─ PlayerManager
 ├─ TrackRuntimeStore
 └─ TrackRuntimeSnapshotBuilder



1. Верхний уровень системы

Проект можно разделить на 6 крупных контуров:
    1.    Доступ к файловой системе
    2.    Реестры и идентичность треков
    3.    Синхронизация фонотеки
    4.    Воспроизведение и плеер
    5.    Треклисты и плейлист плеера
    6.    UI / ViewModel слой

⸻

2. Контур доступа к файловой системе

MusicLibraryManager

Роль: главный координатор доступа к прикреплённым папкам фонотеки.

Отвечает за:
    •    восстановление root-доступа к папкам;
    •    хранение открытых security-scoped root URL;
    •    старт boot pipeline;
    •    публикацию состояния доступа к библиотеке;
    •    запуск sync фонотеки;
    •    формирование лёгкой UI-модели папок.

Не отвечает за:
    •    чтение тегов;
    •    построение waveform;
    •    прямую логику плеера;
    •    ручное управление треками в UI.

Ключевой принцип:
MusicLibraryManager — единственный владелец root access во время runtime.

⸻

BookmarkResolver

Роль: тонкий слой восстановления URL.

Отвечает за:
    •    получение URL трека по trackId;
    •    получение URL папки по folderId;
    •    создание bookmarkData.

Не отвечает за:
    •    startAccessingSecurityScopedResource();
    •    stopAccessingSecurityScopedResource();
    •    хранение открытых доступов;
    •    принятие решений о доступности UI.

Ключевой принцип:
BookmarkResolver ничего не “держит”, а только восстанавливает путь.

⸻

LibraryScanner

Роль: источник фактов о файловой системе.

Отвечает за:
    •    рекурсивный обход папок;
    •    список подпапок;
    •    список найденных аудиофайлов.

Не отвечает за:
    •    идентичность трека;
    •    теги;
    •    bookmark;
    •    удаление/добавление записей в registry.

⸻

3. Реестры и идентичность

TrackIdentityResolver

Роль: выдаёт постоянный trackId для физического файла.

Отвечает за:
    •    вычисление identityKey;
    •    сопоставление identityKey -> trackId;
    •    сохранение этого соответствия.

Ключевой принцип:
trackId рождается только здесь.

⸻

TrackIdentityRegistry

Роль: долговременное хранилище identityMap.

Содержит:
    •    соответствие fingerprint -> UUID.

Нужен для:
    •    стабильности trackId между запусками;
    •    повторного нахождения уже известных файлов.

⸻

TrackRegistry

Роль: реестр метаданных расположения треков и папок.

Отвечает за:
    •    trackId;
    •    fileName;
    •    relativePath;
    •    folderId;
    •    rootFolderId;
    •    список корневых папок.

Не отвечает за:
    •    bookmarkData;
    •    теги трека;
    •    runtime artwork.

Ключевой принцип:
Это главный структурный реестр фонотеки.

⸻

BookmarksRegistry

Роль: реестр bookmarkData.

Отвечает за:
    •    bookmark корневых папок;
    •    bookmark треков;
    •    fallback-доступ к отдельным файлам.

Не отвечает за:
    •    имя трека;
    •    местоположение внутри дерева;
    •    теги.

Ключевой принцип:
BookmarksRegistry хранит доступ, но не описывает структуру библиотеки.

⸻

4. Синхронизация фонотеки

LibrarySyncModule

Роль: синхронизация состояния файловой системы с реестрами.

Отвечает за:
    •    сканирование root-папки;
    •    вычисление trackId через TrackIdentityResolver;
    •    upsert треков в TrackRegistry;
    •    upsert bookmark в BookmarksRegistry;
    •    удаление отсутствующих файлов только в full режиме;
    •    persist реестров только после валидной синхронизации.

Режимы:
    •    safe — только добавление/обновление;
    •    full — добавление/обновление + удаление.

Не отвечает за:
    •    UI;
    •    теги;
    •    доступность строки трека в интерфейсе;
    •    логику плеера.

Ключевой принцип:
LibrarySyncModule — единственное место, где файловая система влияет на TrackRegistry/BookmarksRegistry.

⸻

5. Воспроизведение и плеер

PlayerManager

Роль: низкоуровневое воспроизведение через AVPlayer.

Отвечает за:
    •    создание AVPlayerItem;
    •    play / pause / seek;
    •    текущий доступ к проигрываемому файлу;
    •    progress observer;
    •    Remote Command Center;
    •    Now Playing Info.

Не отвечает за:
    •    выбор следующего трека в бизнес-логике;
    •    хранение состава плейлиста;
    •    загрузку metadata списка.

⸻

PlayerViewModel

Роль: orchestration-слой плеера.

Отвечает за:
    •    текущий воспроизводимый трек;
    •    контекст воспроизведения (плеер / треклист / фонотека);
    •    следующий / предыдущий трек;
    •    синхронизацию прогресса с UI;
    •    работу мини-плеера;
    •    применение TrackRuntimeSnapshot для текущего трека;
    •    реакцию на TrackUpdateEvent.

Ключевой принцип:
PlayerViewModel управляет сценарием воспроизведения, а PlayerManager — самим проигрывателем. Metadata/artwork приходят через runtime snapshot pipeline, а не через прямую загрузку из файла.

⸻

6. Треклисты и плейлист плеера

PlaylistManager

Роль: хранение и загрузка состава player.json.

Отвечает за:
    •    загрузку player.json;
    •    преобразование trackId -> PlayerTrack;
    •    сохранение порядка треков плеера;
    •    деградацию в Недоступно, если URL не восстановлен.

Не отвечает за:
    •    воспроизведение;
    •    AVPlayer;
    •    runtime metadata source of truth.

⸻

TrackListsManager

Роль: хранение списка треклистов.

Отвечает за:
    •    tracklists.json;
    •    список TrackListMeta;
    •    создание / удаление / переименование треклистов.

⸻

TrackListManager

Роль: работа с содержимым одного треклиста.

Отвечает за:
    •    tracklist_<id>.json;
    •    загрузку массива Track;
    •    сохранение массива Track.

⸻

TrackListViewModel

Роль: сценарная логика одного треклиста.

Отвечает за:
    •    загрузку треков;
    •    reorder;
    •    remove;
    •    clear;
    •    refresh доступности через BookmarkResolver;
    •    применение TrackRuntimeSnapshot для строк списка;
    •    реакцию на TrackUpdateEvent.

Ключевой принцип:
Треклист не решает файловый доступ сам. Metadata/artwork для строк приходят через runtime snapshot pipeline.

⸻

7. Metadata и runtime-данные

TrackRuntimeSnapshot

Роль: единый runtime source of truth для актуальных metadata трека.

Содержит:
    •    fileName;
    •    title / artist / album / genre / comment;
    •    расширенные поля sheet;
    •    duration;
    •    artworkData;
    •    isAvailable;
    •    updatedAt.

Ключевой принцип:
UI не читает metadata напрямую из файла. `UIImage` не хранится в snapshot; он создаётся через `ArtworkProvider` как производное представление из `artworkData`.

⸻

TrackRuntimeSnapshotBuilder

Роль: единый сборщик runtime snapshot.

Отвечает за:
    •    восстановление URL через bookmark pipeline;
    •    открытие security-scoped доступа на время чтения;
    •    чтение low-level metadata через TagLib / runtime readers;
    •    сборку TrackRuntimeSnapshot.

Не отвечает за:
    •    публикацию notification;
    •    хранение snapshot;
    •    обновление UI.

⸻

TrackRuntimeStore

Роль: централизованное runtime-хранилище последних snapshot по trackId.

Отвечает за:
    •    сохранение актуального TrackRuntimeSnapshot;
    •    выдачу snapshot без повторного чтения файла;
    •    очистку snapshot при инвалидации.

Не отвечает за:
    •    чтение файла;
    •    публикацию событий;
    •    преобразование artworkData в UIImage.

⸻

TrackUpdateCoordinator

Роль: единый post-update coordinator для metadata, artwork, rename и move.

Отвечает за:
    •    инвалидацию technical caches;
    •    запуск TrackRuntimeSnapshotBuilder;
    •    сохранение snapshot в TrackRuntimeStore;
    •    публикацию TrackUpdateEvent через .trackDidUpdate.

Не отвечает за:
    •    запись тегов;
    •    прямую работу с UI.

⸻

TrackMetadataCacheManager

Роль: technical raw-cache metadata/artwork для runtime pipeline.

Отвечает за:
    •    кэширование сырых title / artist / duration / artworkData;
    •    дедупликацию и throttling низкоуровневого чтения;
    •    инвалидацию по URL.

Не отвечает за:
    •    UI-facing metadata contract;
    •    источник истины для экранов;
    •    хранение UIImage.

Ключевой принцип:
Это технический cache ниже snapshot pipeline. UI/ViewModel не вызывают `TrackMetadataCacheManager.shared.loadMetadata`.

⸻

8. Модели проекта

LibraryTrack

Модель строки трека в фонотеке.

Track

Модель строки трека в треклисте.

PlayerTrack

Модель строки трека в плейлисте плеера.

Ключевой принцип:
Эти модели могут различаться по UI-задаче, но должны опираться на один и тот же trackId.

⸻

9. UI / ViewModel слой

UI-слой строится поверх менеджеров и реестров.

Общее правило:
    •    View — только отображение и пользовательские события;
    •    ViewModel — сценарная логика экрана;
    •    Manager / Module / Registry — системный слой;
    •    Resolver — специализированное восстановление/поиск;
    •    Cache — только runtime-ускорение.

⸻

10. Главные архитектурные правила проекта

Правило 1

Root access держит только MusicLibraryManager.

Правило 2

BookmarkResolver не управляет жизненным циклом доступа.

Правило 3

trackId создаётся только через TrackIdentityResolver.

Правило 4

Только LibrarySyncModule изменяет TrackRegistry и BookmarksRegistry по фактам файловой системы.

Правило 5

Доступность трека определяется через возможность восстановить URL, а не через fileExists.

Правило 6

Metadata и artwork — runtime-данные. Runtime source of truth для экранов — TrackRuntimeSnapshot.

Правило 7

UI не должен принимать системные решения о доступе к файлам.

Правило 8

После изменения tags/artwork/rename/move обновление проходит через TrackUpdateCoordinator и TrackUpdateEvent, а не через слабое notification с trackId.

Правило 9

UI не вызывает TagLib и не вызывает TrackMetadataCacheManager.shared.loadMetadata.

⸻

11. Точки риска, которые нужно помнить

1. Рассинхрон между несколькими хранилищами

Пока проект живёт на нескольких JSON, всегда есть риск расхождения между:
    •    TrackRegistry
    •    BookmarksRegistry
    •    TrackIdentityRegistry
    •    player.json
    •    tracklists.json
    •    tracklist_<id>.json

2. Нарушение boot pipeline

Любой новый менеджер, стартующий раньше libraryAccessRestored, может снова создать плавающий баг.

3. Возврат локальных проверок доступности

Если где-то снова появится fileExists для UI-доступности трека, система снова станет нестабильной после reboot.

⸻

12. Куда класть новые фичи

Если фича про доступ к папкам / bookmark / восстановление

Смотреть в:
    •    MusicLibraryManager
    •    BookmarkResolver
    •    BookmarksRegistry

Если фича про физическое состояние файловой системы

Смотреть в:
    •    LibraryScanner
    •    LibrarySyncModule
    •    TrackIdentityResolver
    •    TrackRegistry

Если фича про воспроизведение

Смотреть в:
    •    PlayerManager
    •    PlayerViewModel

Если фича про состав плеера / треклиста

Смотреть в:
    •    PlaylistManager
    •    TrackListManager
    •    TrackListsManager
    •    TrackListViewModel

Если фича про metadata / artwork

Смотреть в:
    •    TrackRuntimeSnapshot
    •    TrackRuntimeSnapshotBuilder
    •    TrackRuntimeStore
    •    TrackUpdateCoordinator
    •    RuntimeMetadataParser
    •    TrackMetadataCacheManager как technical cache
    •    ArtworkProvider

Если фича только UI

Смотреть в:
    •    View
    •    ViewModel
    •    Modifier
    •    Toolbar
    •    Sheet
