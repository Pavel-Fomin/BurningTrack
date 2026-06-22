# Назначение

TagLib — внешняя интеграция BurningTrack для чтения и записи metadata музыкальных треков.

Документ фиксирует архитектурную роль TagLib как технологии ниже пользовательских сценариев и runtime-контрактов. Он не описывает внутреннее устройство библиотеки, перечень поддерживаемых данных или детали подключения.

# Роль в архитектуре

TagLib находится в слое внешних интеграций.

Его задача — дать проекту возможность читать metadata из физического трека и применять подтверждённые изменения metadata через проектные архитектурные контракты.

Feature-подсистемы не используют TagLib как самостоятельный контракт. Они работают с Runtime Metadata, Track Identity и своими feature-flow, а TagLib остаётся технической интеграцией ниже этих уровней.

# Основной поток

```text
Feature-сценарий запрашивает данные или изменение трека
↓
Track Identity определяет физический трек
↓
Runtime Metadata или Track Edit Session использует интеграцию TagLib
↓
TagLib получает данные для чтения или записи metadata
↓
TagLib передаёт результат в проектный контракт
↓
Результат возвращается через соответствующий архитектурный контракт.
```

# Участвующие подсистемы

- Runtime Metadata — Runtime Metadata использует TagLib для получения актуальных metadata трека.
- Track Edit Session — Track Edit Session использует TagLib для применения подтверждённых изменений metadata.
- Track Identity — TagLib использует Track Identity для связи операции с физическим треком через проектный контракт.

# Контракты

- TagLib отвечает за интеграцию внешней технологии чтения и записи metadata.
- TagLib используется только ниже проектных runtime и feature-контрактов.
- TagLib получает контекст операции из проектного контракта, а не из UI.
- TagLib передаёт результат чтения или записи обратно в проектный контракт.
- Runtime Metadata использует результат работы TagLib для обновления своего состояния.

# Ограничения

- TagLib не является пользовательской feature-подсистемой.
- TagLib не определяет screen-flow, navigation-flow или presentation-flow.
- TagLib не определяет Track Identity.
- TagLib не определяет Runtime Metadata как публичный контракт приложения.
- TagLib не принимает пользовательские решения.
- TagLib не определяет способ представления ошибок или успешных результатов.
- TagLib не описывает правила Track Edit Session.

# Связанные документы

- [Documentation Rules](../Developer/Documentation%20Rules.md)
- [Overview](../Architecture/Overview.md)
- [Runtime Metadata](../Architecture/Runtime%20Metadata.md)
- [Track Identity](../Architecture/Track%20Identity.md)
- [Track Edit Session](../Features/Track%20Edit%20Session.md)
