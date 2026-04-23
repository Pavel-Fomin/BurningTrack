# TagLib Integration

## Общая схема интеграции

TagLib встроен в репозиторий проекта как `xcframework`:

`Libraries/taglib/taglib.xcframework`

Внутри `xcframework` лежит статическая библиотека `libtag_full.a` и набор C++ headers TagLib.

Интеграция построена на **чистом C++ API TagLib через Objective-C++ обёртки**:

- основной код использует C++ API TagLib из `.mm` файлов
- Swift работает только через проектные обёртки
- C API (`tag_c`) полностью удалён из проекта и сборки

Схема:

Swift  
↓  
Objective-C++ (.mm)  
↓  
TagLib (C++)

## Источник библиотеки

Источник TagLib:  
`https://taglib.org/releases/taglib-2.2.1.tar.gz`

Текущая версия: `2.2.1`

Версия подтверждается заголовками:

- `Libraries/taglib/taglib.xcframework/ios-arm64/Headers/taglib.h`
- `Libraries/taglib/taglib.xcframework/ios-arm64-simulator/Headers/taglib.h`

В них указано:

- `TAGLIB_MAJOR_VERSION 2`
- `TAGLIB_MINOR_VERSION 2`
- `TAGLIB_PATCH_VERSION 1`

Формат текущего артефакта: исходный архив TagLib `tar.gz` → сборка статических библиотек → упаковка в `taglib.xcframework`.

В репозитории хранится уже готовый `xcframework`; исходный `tar.gz` и build-скрипты сборки TagLib рядом не хранятся.

## Структура xcframework

`Libraries/taglib/taglib.xcframework/Info.plist` содержит две платформенные библиотеки:

- `ios-arm64`
- `ios-arm64-simulator`

В обеих платформах лежит:

- `libtag_full.a`
- C++ headers TagLib

Архитектура обеих статических библиотек: `arm64`.

Критично:

- `tag_c.h` отсутствует
- `libtag_c*` отсутствует
- C API symbols отсутствуют
- C++ symbols `TagLib::*` присутствуют

Примеры C++ headers внутри `Headers`:

- `fileref.h`
- `tag.h`
- `tstring.h`
- `tpropertymap.h`
- `mpeg/mpegfile.h`
- `mpeg/id3v2/id3v2tag.h`
- `mpeg/id3v2/frames/attachedpictureframe.h`
- `flac/flacfile.h`
- `flac/flacpicture.h`
- `ogg/xiphcomment.h`
- `ogg/vorbis/vorbisfile.h`
- `ogg/opus/opusfile.h`

`taglib_config.h` включает поддержку нескольких форматов, включая:

- `APE`
- `ASF`
- `DSF`
- `MATROSKA`
- `MOD`
- `MP4`
- `RIFF`
- `SHORTEN`
- `TRUEAUDIO`
- `VORBIS`

## Подключение в Xcode

Проект использует Xcode file-system-synchronized groups. `Libraries` добавлена в проект как синхронизированная группа, а сборка запускает:

`ProcessXCFramework Libraries/taglib/taglib.xcframework`

В результате Xcode копирует выбранный слайс в build products:

- `Build/Products/.../libtag_full.a`
- `Build/Products/.../include/...`

В классической секции `PBXFrameworksBuildPhase` явно виден только `libz.tbd`. Отдельного обычного `PBXBuildFile` для `taglib.xcframework` в `Frameworks` phase нет, но `xcframework` всё равно обрабатывается сборочной системой через synchronized group.

Дополнительные linker flags:

- `OTHER_LDFLAGS = ""`
- ручного `-ltag` нет
- ручного `-lc++` нет

Дополнительные C++ flags:

- `OTHER_CPLUSPLUSFLAGS = $(OTHER_CFLAGS) -DTAGLIB_DISABLE_TFILE`

Стандарт C++:

- `CLANG_CXX_LANGUAGE_STANDARD = gnu++20`

`libc++` вручную в `Link Binary With Libraries` не добавлен. C++ runtime подключается сборочной системой Xcode/clang автоматически, так как target содержит Objective-C++ `.mm` файлы и линкуется со стандартными библиотеками (`LINK_WITH_STANDARD_LIBRARIES = YES`).

Также подключён `libz.tbd`, так как TagLib использует zlib-зависимости для части форматов и сжатых данных.

## Bridging

Bridging Header находится здесь:

`TrackList-Bridging-Header.h`

Через него подключаются:

- `"TLTagLibFile.h"`
- `"TLTagLibTagWriter.h"`

`tag_c.h` через bridging header больше не подключается. Swift-мост содержит только проектные Objective-C / Objective-C++ обёртки.

## Обёртки

### TLTagLibFile

Файлы:

- `TrackList/Managers/TagLibReader/TLTagLibFile.h`
- `TrackList/Managers/TagLibReader/TLTagLibFile.mm`
- `TrackList/Managers/TagLibReader/TLTagLibFile.swift`

Роль: чтение тегов.

`TLTagLibFile.mm` использует C++ API TagLib:

- `TagLib::FileRef`
- `TagLib::Tag`
- `TagLib::PropertyMap`
- `TagLib::MPEG::File`
- `TagLib::FLAC::File`
- `TagLib::Ogg::Vorbis::File`
- `TagLib::Ogg::Opus::File`

Читает:

- title
- artist
- album
- genre
- comment
- year
- publisher / label / organization через `PropertyMap`
- artwork для MP3, FLAC, Vorbis, Opus

Swift-класс `TLTagLibFile` вызывает Objective-C функцию `_readMetadata(filePath)` и преобразует результат в Swift-модель `ParsedMetadata`.

### TLTagLibTagWriter

Файлы:

- `TrackList/Managers/TagLibWriter/TLTagLibTagWriter.h`
- `TrackList/Managers/TagLibWriter/TLTagLibTagWriter.mm`
- `TrackList/Managers/TagLibWriter/TagLibTagsWriter.swift`

Роль: запись тегов.

`TLTagLibTagWriter.mm` использует C++ API TagLib. Комментарий в `.h` про C API устарел.

Пишет:

- title
- artist
- album
- genre
- comment
- year
- track number
- publisher через `PropertyMap`
- BPM через `PropertyMap`
- artwork для MP3, FLAC, Vorbis, Opus

Swift-класс `TagLibTagsWriter` реализует протокол `TagsWriter`, мапит `TagWritePatch` в Objective-C enum/action параметры и вызывает `_writeBasicTags(...)`.

## Использование в проекте

### Чтение тегов

Runtime-чтение для списков и плеера:

- `TrackList/Managers/RuntimeMetadataParser.swift`
- вызывает `TLTagLibFile(fileURL: url).readMetadata(duration:)`

Кешированный доступ:

- `TrackList/Managers/MetadataCacheManager.swift`
- `TrackMetadataCacheManager.shared.loadMetadata(for:)`
- внутри вызывает `RuntimeMetadataParser.parseMetadata(from:)`

Инспекция тегов для экрана информации/редактирования:

- `TrackList/Managers/TrackTagInspector.swift`
- вызывает `TLTagLibFile(fileURL: url).readMetadata()`

Дополнительное чтение artwork в UI:

- `TrackList/Views/Shared/Sheets/TrackDetailSheet.swift`
- `TrackList/Views/Shared/Sheets/TrackDetailContainer.swift`

### Запись тегов

Основная точка записи:

- `TrackList/Domain/AppCommandExecutor.swift`
- метод `updateTrackTags(trackId:patch:artworkAction:)`

Цепочка записи:

- `AppCommandExecutor`
- `TagsWriter`
- `TagLibTagsWriter`
- `_writeBasicTags(...)`
- `TLTagLibTagWriter.mm`
- `TagLib::FileRef.save()`

После успешной записи:

- инвалидируется `TrackMetadataCacheManager`
- инвалидируется `ArtworkProvider`
- отправляется `.trackMetadataDidChange`
- метаданные загружаются заново для toast / UI

## Важные особенности

Security-scoped доступ не находится внутри TagLib-обёрток. Обёртки принимают обычный путь к файлу и предполагают, что доступ уже открыт выше по стеку.

При записи `AppCommandExecutor.updateTrackTags(...)` делает:

- `BookmarkResolver.url(forTrack:)`
- `url.startAccessingSecurityScopedResource()`
- запись через `TagLibTagsWriter`
- `url.stopAccessingSecurityScopedResource()`

При чтении доступ зависит от вызывающего кода:

- `TrackDetailSheet.loadMetadataAndArtwork(from:)` открывает security-scoped доступ перед чтением
- `RuntimeMetadataParser` и `TrackMetadataCacheManager` сами доступ не открывают
- `TrackDetailContainer.reloadSheetMetadataFromFile()` резолвит URL через bookmark, но явно не вызывает `startAccessingSecurityScopedResource()`

Метаданные кешируются в `TrackMetadataCacheManager` через `NSCache<NSURL, CachedMetadata>`:

- `countLimit = 100`
- `totalCostLimit = 30 MB`
- artwork хранится как raw `Data`
- после записи тегов кеш инвалидируется по URL

Обложки дополнительно проходят через `ArtworkProvider`, где есть отдельный image cache.

Ограничения текущей записи artwork:

- поддержаны MP3 ID3v2 `APIC`
- поддержан FLAC `Picture`
- поддержаны Vorbis / Opus через Xiph pictures
- для других форматов `TLApplyArtwork(...)` возвращает unsupported format, если запрошено изменение artwork

## Что НЕ используется

Старый `tag_c-only` подход полностью удалён из текущего проекта и сборки.

`tag_c.h` отсутствует в текущем `xcframework`; рабочие обёртки чтения и записи используют только C++ API TagLib.

Прямые вызовы C API TagLib в коде проекта не используются.

Backup-папки TagLib не участвуют в сборке. Xcode обрабатывает только `Libraries/taglib/taglib.xcframework`.

## Потенциальные проблемы

Комментарии в нескольких файлах устарели:

- `TLTagLibTagWriter.h` говорит про запись через TagLib C API, но реализация в `TLTagLibTagWriter.mm` использует C++ API
- `TLTagLibFile.swift` говорит про C API, но фактически вызывает проектную Objective-C++ обёртку над C++ API

В `project.pbxproj` на уровне project build settings есть:

`FRAMEWORK_SEARCH_PATHS = "$(PROJECT_DIR)/Libraries/Taglib"`

Здесь отличается регистр (`Taglib` вместо `taglib`). Target-level настройки и `ProcessXCFramework` сейчас позволяют сборке находить заголовки через build products, но project-level путь выглядит устаревшим / неиспользуемым.

`TrackDetailContainer.reloadSheetMetadataFromFile()` читает TagLib-метаданные после `BookmarkResolver.url(forTrack:)`, но без явного `startAccessingSecurityScopedResource()`. Если URL требует security-scoped access и доступ не открыт выше, чтение может быть нестабильным.

## Итог

Интеграция:

- полностью переведена на C++ API
- не содержит legacy-слоёв
- не зависит от `tag_c`
- соответствует целевой архитектуре проекта
