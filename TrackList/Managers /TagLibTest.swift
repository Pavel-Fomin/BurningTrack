//
//  TagLibTest.swift
//  TrackList
//
//  Created by Pavel Fomin on 19.06.2025.
//

import Foundation

// C API доступен через Bridging Header или import tag_c, если modulemap работает
// Пример: читаем title через обёртку

func testTagLibCAPI() {
    let path = "/some/file/path.mp3" // тестовый путь
    guard let cPath = path.cString(using: .utf8) else {
        print("❌ Не удалось преобразовать путь")
        return
    }

    let file = taglib_file_new(cPath)
    if let tag = taglib_file_tag(file) {
        if let title = taglib_tag_title(tag) {
            print("✅ Title: \(String(cString: title))")
        } else {
            print("⚠️ Title не найден")
        }
    } else {
        print("⚠️ Теги не найдены")
    }

    taglib_file_free(file)
}
