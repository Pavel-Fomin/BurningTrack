//
//  ToastView+Preview.swift
//  TrackList
//
//  Xcode Preview для уведомления Toast.
//
//  Created by Pavel Fomin on 13.06.2026.
//

#if DEBUG
import SwiftUI

/// Размещает ToastView на нейтральном фоне для визуальной проверки.
private struct ToastViewPreviewContainer: View {
    let data: ToastData

    var body: some View {
        VStack {
            Spacer()
            ToastView(data: data)
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Успешное действие — iPhone") {
    ToastViewPreviewContainer(
        data: ToastData(
            style: .track(
                title: "Midnight Drive",
                artist: "Neon Coast"
            ),
            artworkImage: Image(systemName: "music.note"),
            message: "Добавлен в треклист"
        )
    )
}

#Preview("Предупреждение — iPhone") {
    ToastViewPreviewContainer(
        data: ToastData(
            style: .trackList(name: "Дорожная музыка"),
            artworkImage: nil,
            message: "Некоторые треки недоступны"
        )
    )
}

#Preview("Ошибка — iPhone") {
    ToastViewPreviewContainer(
        data: ToastData(
            style: .trackList(name: "Не удалось сохранить"),
            artworkImage: nil,
            message: "Операция завершилась с ошибкой"
        )
    )
}

#Preview("Длинный текст — iPhone") {
    ToastViewPreviewContainer(
        data: ToastData(
            style: .track(
                title: "Очень длинное название трека для проверки ограничения ширины текста",
                artist: "Исполнитель с очень длинным названием"
            ),
            artworkImage: Image(systemName: "music.note.list"),
            message: "Добавлен в треклист с очень длинным названием"
        )
    )
}

#Preview("Успешное действие — iPad") {
    ToastViewPreviewContainer(
        data: ToastData(
            style: .track(
                title: "Northern Lights",
                artist: "Glass Harbor"
            ),
            artworkImage: Image(systemName: "music.note"),
            message: "Добавлен в плеер"
        )
    )
}
#endif
