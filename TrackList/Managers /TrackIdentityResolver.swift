//
//  TrackIdentityResolver.swift
//  TrackList
//
//  Слой идентичности файлов.
//
//  Ответственность:
//  — определить identityKey физического файла
//  — выдать постоянный trackId для этого файла
//  — хранить соответствие identityKey → trackId
//
//  ВАЖНО:
//  — trackId создаётся ТОЛЬКО здесь
//  — trackId не зависит от URL, пути или имени файла
//  — URL рассматривается как временный способ доступа
//
//  Приоритет идентичности:
//  1) fileResourceIdentifier (если доступен)
//  2) fingerprint (fallback)
//
//  Created by Pavel Fomin on 30.12.2025.
//

import Foundation
import CryptoKit

actor TrackIdentityResolver {

    static let shared = TrackIdentityResolver()

    // MARK: - Хранилище соответствий

    /// identityKey → trackId
    private var identityMap: [String: UUID] = [:]

    private var isLoaded = false

    // MARK: - Путь к файлу хранения

    private let fileURL: URL = {
        let dir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        return dir.appendingPathComponent("TrackIdentityRegistry.json")
    }()

    // MARK: - Публичный API

    /// Возвращает постоянный trackId для физического файла.
    /// Если файл встречается впервые — создаёт новый trackId.
    func trackId(for url: URL) async -> UUID {
        await loadIfNeeded()

        guard let identityKey = identityKey(for: url) else {
            // Крайний случай: если не удалось определить идентичность,
            // создаём новый trackId, но это считается исключением.
            return UUID()
        }

        if let existing = identityMap[identityKey] {
            return existing
        }

        let newId = UUID()
        identityMap[identityKey] = newId
        await persist()
        return newId
    }

    // MARK: - IdentityKey

    /// Определяет identityKey физического файла.
    private func identityKey(for url: URL) -> String? {

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // 1. Приоритет: fileResourceIdentifier
        if let resourceId = resourceIdentifier(for: url) {
            return "rid:\(resourceId)"
        }

        // 2. Fallback: fingerprint
        if let fingerprint = fingerprint(for: url) {
            return "fp:\(fingerprint)"
        }

        return nil
    }

    // MARK: - Resource Identifier

    private func resourceIdentifier(for url: URL) -> String? {
        do {
            let values = try url.resourceValues(forKeys: [.fileResourceIdentifierKey])

            if let data = values.fileResourceIdentifier as? Data {
                return data.base64EncodedString()
            }

            if let any = values.fileResourceIdentifier {
                return String(describing: any)
            }

            return nil
        } catch {
            return nil
        }
    }

    // MARK: - Fingerprint

    private func fingerprint(for url: URL) -> String? {
        do {
            let values = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .contentModificationDateKey,
                .nameKey
            ])

            let size = values.fileSize ?? 0
            let modified = values.contentModificationDate?.timeIntervalSince1970 ?? 0
            let name = values.name ?? url.lastPathComponent

            let head = try readChunk(from: url, offset: 0, length: 64 * 1024)

            let tail: Data
            if size > 128 * 1024 {
                tail = try readChunk(
                    from: url,
                    offset: max(0, size - 64 * 1024),
                    length: 64 * 1024
                )
            } else {
                tail = Data()
            }

            var hasher = SHA256()
            hasher.update(data: Data("\(name)|\(size)|\(modified)".utf8))
            hasher.update(data: head)
            hasher.update(data: tail)

            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined()

        } catch {
            return nil
        }
    }

    private func readChunk(from url: URL, offset: Int, length: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        try handle.seek(toOffset: UInt64(offset))
        return try handle.read(upToCount: length) ?? Data()
    }

    // MARK: - Загрузка / сохранение

    private func loadIfNeeded() async {
        guard !isLoaded else { return }
        isLoaded = true

        do {
            let data = try Data(contentsOf: fileURL)
            identityMap = try JSONDecoder().decode([String: UUID].self, from: data)
        } catch {
            identityMap = [:]
        }
    }

    private func persist() async {
        do {
            let data = try JSONEncoder().encode(identityMap)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Ошибка сохранения не должна валить приложение.
        }
    }
}
