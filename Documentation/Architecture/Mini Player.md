# Назначение

Mini Player — это общий presentation-контракт текущего playback-состояния в BurningTrack.

Он нужен, чтобы пользователь видел активное воспроизведение и мог отправлять базовые playback-намерения из разных root screens без перехода в Player.

Mini Player не является самостоятельной feature-подсистемой, не владеет playback-логикой и не определяет структуру экранов. Его архитектурная роль — дать root screens единый способ подключать playback presentation поверх собственных сценариев.

# Проблема

Если Mini Player становится частью конкретного Feature Flow, он начинает зависеть от локальных правил этой feature-подсистемы.

Это создаёт несколько проблем:

- один root screen получает особые правила подключения playback presentation;
- дочерние UI-компоненты начинают решать, где и когда показывать общий playback-контекст;
- Mini Player может начать владеть playback-состоянием вместо отображения готового состояния;
- пользовательские playback-намерения могут обрабатываться внутри чужого feature-flow;
- Mini Player может быть ошибочно воспринят как navigation-сущность или отдельная точка входа сценария;
- изменение способа отображения начинает требовать изменений в отдельных экранах.

Единый контракт нужен, чтобы Mini Player оставался общей presentation-подсистемой, подключаемой на границе root screen, и не смешивался с feature-flow, Navigation или Player.

# Архитектурная схема

Место Mini Player в архитектуре BurningTrack:

```text
Application
↓
Root Screens
↓
Screen Integration
↓
Mini Player Contract
↓
Feature UI
```

Поток состояния для Mini Player:

```text
Playback State
↓
Playback Presentation State
↓
Mini Player
↓
UI
```

Схема показывает архитектурное положение Mini Player. Она не описывает визуальное расположение или способ отображения на экране.

# Основные компоненты

## Mini Player Contract

Mini Player Contract определяет общую presentation-роль Mini Player в приложении.

Он задаёт, что Mini Player отображает текущий playback-контекст поверх root screens и отправляет playback-намерения обратно в Player. Этот контракт не владеет playback-логикой, feature-сценариями или navigation.

## Playback Presentation State

Playback Presentation State — готовое состояние Mini Player для отображения.

Оно строится из текущего playback-состояния и готовых данных трека. Это состояние не является источником playback, не хранит пользовательский сценарий и может быть пересобрано при изменении playback или runtime-данных.

## Screen Integration

Screen Integration описывает подключение Mini Player на границе root screen.

Root Screen подключает общий Mini Player к своему screen-flow, но не управляет внутренней playback-логикой Mini Player. Дочерние UI-компоненты не должны подключать Mini Player самостоятельно.

# Поток данных

Типовой поток состояния Mini Player:

```text
Playback State
↓
Playback Presentation State
↓
Mini Player
↓
UI
```

Типовой поток пользовательского действия:

```text
Пользовательское действие в Mini Player
↓
Playback-намерение
↓
Player
↓
Обновлённое Playback State
↓
Playback Presentation State
↓
Mini Player
```

Mini Player получает готовое состояние и возвращает только playback-намерения. Изменение playback-состояния происходит в Player и затем снова попадает в Mini Player как обновлённое presentation-состояние.

# Контракты

- Mini Player является общей presentation-подсистемой приложения.
- Mini Player не принадлежит отдельной feature-подсистеме.
- Mini Player не становится владельцем Playback.
- Mini Player отображает готовое Playback Presentation State.
- Root Screen подключает Mini Player, но не управляет его внутренней playback-логикой.
- Дочерние UI-компоненты не подключают Mini Player самостоятельно.
- Mini Player отправляет playback-намерения в Player и не выполняет системные операции напрямую.
- Mini Player не становится Navigation и не определяет переходы между сценариями.
- Mini Player не содержит бизнес-логику feature-подсистем.
- Изменение способа отображения Mini Player не должно менять его архитектурный контракт.

# Инварианты

- В приложении существует один общий Mini Player.
- Mini Player не определяет структуру экранов.
- Mini Player не становится источником Playback State.
- Mini Player не становится владельцем пользовательского сценария.
- Mini Player не становится владельцем состояния других архитектурных подсистем, включая Player.
- Mini Player не подменяет Navigation, Sheets или Errors and Toasts.
- Способ отображения Mini Player может измениться без изменения архитектурного контракта.
- Playback-намерения из Mini Player должны возвращаться в Player.

# Зависимости

Mini Player используется документами и будущими каноничными описаниями следующих подсистем:

- Overview — место Mini Player среди общих presentation-подсистем BurningTrack.
- Root Screens — правила подключения Mini Player на границе root screen.
- Navigation — отделение Mini Player от переходов между сценариями.
- Player — источник playback-состояния и обработка playback-намерений.
- Runtime Metadata — готовые данные трека для playback presentation.

# Документы, раскрывающие отдельные аспекты архитектуры

- [Overview](Overview.md)
- [Root Screens](Root%20Screens.md)
- [Navigation](Navigation.md)
- Player
- Runtime Metadata
