# Mini Player

Документ описывает архитектуру мини-плеера, правила его подключения, модель layout reservation и hit-testing.

## Назначение

Мини-плеер отображает текущий трек поверх экранов вкладок и предоставляет быстрые действия:

- play/pause по header;
- переключение треков свайпом по header;
- seek через progress bar;
- AirPlay route picker;
- визуальное отображение обложки, исполнителя, названия и прогресса.

Мини-плеер не должен ломать scrollable content под ним. Экран, на котором он отображается, обязан резервировать нижнюю область так, чтобы списки, формы и pushed screens не уходили под карточку.

## Уровень подключения

Мини-плеер подключается на уровне screen, к корневому `NavigationStack` конкретной вкладки.

Это важно по двум причинам:

- reservation применяется к тому content tree, который реально должен сдвигаться;
- pushed screens внутри `NavigationStack` получают тот же нижний layout contract.

Каноничный способ подключения:

```swift
.miniPlayerHost(
    trackListViewModel: trackListViewModel,
    playerViewModel: playerViewModel
)
```

Прямое подключение `MiniPlayerView` в экранах не используется. Все screen-level правила сосредоточены в `MiniPlayerHostModifier`.

## MiniPlayerHostModifier

`MiniPlayerHostModifier` является единственным layout host для мини-плеера.

Ответственность modifier:

- проверить, есть ли текущий трек;
- зарезервировать нижнюю область экрана;
- отрисовать визуальный слой мини-плеера;
- сохранить визуальный отступ карточки от нижней системной области;
- не управлять playback-логикой;
- не управлять жестами внутренних частей мини-плеера.

Playback-логика находится в `PlayerViewModel`. Состав UI находится в `MiniPlayerView`, `MiniPlayerHeaderView` и `MiniPlayerProgressView`.

## Reservation и visual layer

В host используются два разных SwiftUI-механизма.

`safeAreaInset(edge: .bottom)` используется только для reservation. Внутри него находится прозрачная область фиксированной высоты. Она участвует в layout и не рисует реальный mini player.

`overlay(alignment: .bottom)` используется только для visual layer. Внутри него находится реальный `MiniPlayerView`, который пользователь видит и с которым взаимодействует.

Такое разделение нужно, чтобы:

- scrollable content получал стабильный нижний inset;
- визуальная карточка могла лежать поверх экрана;
- layout reservation не зависел от hit-testing карточки;
- host оставался единственной точкой подключения mini player.

Нельзя заменять reservation ручными spacer-ами внутри экранов. Нельзя использовать overlay как единственный способ размещения mini player, потому что overlay сам по себе не резервирует место для контента.

## Fixed reservation height

Высота reservation фиксирована и хранится именованной константой в `MiniPlayerHostModifier`.

Фиксированный reservation выбран сознательно:

- высота mini player предсказуема по текущему UI;
- dynamic measurement усложняет host и может создать layout feedback loop;
- measurement должен учитывать не только внутреннюю карточку, но и внешний bottom padding host;
- текущему UI не нужна runtime-подстройка высоты.

Если меняется вертикальный layout mini player, нужно пересчитать reservation-константу и проверить все вкладки, включая pushed screens.

## Hit-testing

Hit-testing разделен по функциональным зонам.

### Header

`MiniPlayerHeaderView` отвечает за верхнюю часть mini player.

Внешний header `HStack` имеет:

- `frame(height: 40)`;
- `contentShape(Rectangle())`;
- tap gesture для play/pause;
- drag gesture для next/previous.

Tap должен работать по всей ширине header. Swipe должен работать по всей ширине header, включая пустую область рядом с AirPlay.

### Progress

`MiniPlayerProgressView` отвечает за progress row и передает seek в `PlayerViewModel`.

`ProgressBar` имеет собственный `DragGesture(minimumDistance: 0)` и сам обрабатывает seek. Host и `MiniPlayerView` не должны накрывать `ProgressBar` blocker-ом.

### Blocker zones

`MiniPlayerView` содержит точечные blocker-зоны только в пустых местах карточки:

- между `MiniPlayerHeaderView` и `MiniPlayerProgressView`;
- под `MiniPlayerProgressView`, если там есть пустая область.

Blocker-зоны гасят свайпы по пустым частям карточки, чтобы не прокручивался список под mini player.

Глобальный blocker gesture на всю glass-карточку запрещен, потому что он может конфликтовать с header swipe и progress seek.

## Запрещенные паттерны

В mini player subsystem запрещены:

- root overlay над `TabView`;
- ручные bottom spacer-ы под mini player внутри экранов;
- `safeTabBarInset`;
- глобальный blocker gesture на всю glass-карточку;
- прямое подключение `MiniPlayerView` вне `MiniPlayerHostModifier`;
- альтернативные wrapper-компоненты для mini player;
- dynamic measurement через `MiniPlayerHeightPreferenceKey`;
- inline magic numbers для reservation height.

Эти паттерны нарушают разделение между reservation, visual layer и hit-testing.

## Каноничные файлы

Каноничные файлы mini player subsystem:

- `TrackList/Views/MiniPlayer/MiniPlayerHostModifier.swift` - screen-level host, reservation и visual overlay;
- `TrackList/Views/MiniPlayer/MiniPlayerView.swift` - glass-карточка mini player и blocker-зоны;
- `TrackList/Views/MiniPlayer/MiniPlayerHeaderView.swift` - header, tap play/pause и swipe next/previous;
- `TrackList/Views/MiniPlayer/MiniPlayerProgressView.swift` - progress row и передача seek;
- `TrackList/Views/Shared/Components/ProgressBar.swift` - интерактивный progress bar;
- `TrackList/Models/MiniPlayer/MiniPlayerState.swift` - модели состояния mini player;
- `TrackList/Helpers/MiniPlayerStateBuilder.swift` - сборка отображаемого состояния mini player;
- `TrackList/ViewModels/Player/PlayerViewModel.swift` - источник playback-состояния и действий.

## Правила изменения

При изменении mini player нужно проверять:

- совпадает ли reservation height с фактической визуальной высотой;
- не накрывают ли blocker-зоны header или progress;
- работает ли tap по всей ширине header;
- работает ли swipe по header;
- работает ли seek в progress bar;
- не прокручивается ли список при свайпе по пустым зонам карточки;
- не блокируются ли зоны за пределами карточки;
- корректно ли ведут себя pushed screens внутри вкладок.

Изменения layout mini player должны проходить через `MiniPlayerHostModifier` и каноничные mini player views, без добавления новых wrapper-слоев.

