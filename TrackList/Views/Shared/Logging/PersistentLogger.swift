//
//  PersistentLogger.swift
//  TrackList
//
//  Пишет логи в файл внутри Documents.
//  Используется для диагностики проблем после reboot,
//  когда Xcode-консоль недоступна.
//
//  Created by Pavel Fomin on 15.02.2026.
//

import Foundation

enum PersistentLogger {

    private static let fileName = "tracklist_debug.log"
    private static let queue = DispatchQueue(label: "PersistentLogger.queue")

    private static var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(fileName)
    }

    static func log(_ message: String) {
        let timestamp = Self.makeTimestamp()
        let line = "[\(timestamp)] \(message)\n"

        queue.async {
            guard let url = fileURL else { return }

            if FileManager.default.fileExists(atPath: url.path) == false {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }

            guard let data = line.data(using: .utf8) else { return }

            do {
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }

                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                // Если даже логгер не может писать — уже ничего не сделаем.
                // Здесь intentionally no print.
            }
        }
    }

    static func clear() {
        queue.async {
            guard let url = fileURL else { return }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func makeTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}
