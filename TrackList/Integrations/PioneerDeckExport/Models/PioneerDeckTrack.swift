//
//  PioneerDeckTrack.swift
//  TrackList
//
//  Модель трека для writer-слоя Pioneer/AlphaTheta USB Export.
//

import Foundation

/// Уникальный трек, который будет записан в export.pdb и связан с ANLZ-файлами.
public struct PioneerDeckTrack: Equatable, Sendable {
    /// Числовой id трека внутри export.pdb.
    public let id: UInt32

    /// Исходный UUID трека BurningTrack.
    public let sourceTrackId: UUID

    /// Название трека для отображения на деке.
    public let title: String

    /// Исполнитель для отображения на деке.
    public let artist: String

    /// Длительность в секундах.
    public let durationSeconds: UInt32

    /// Sample rate аудиофайла, если он достоверно известен.
    public let sampleRate: UInt32?

    /// Размер аудиофайла в байтах для u4 поля track_row.
    public let fileSize: UInt32?

    /// Bit depth аудиофайла, если он достоверно известен.
    public let sampleDepth: UInt16?

    /// Bitrate аудиофайла, если он достоверно известен.
    public let bitrate: UInt32?

    /// BPM * 100, если tempo уже есть в domain-данных.
    public let tempoX100: UInt32?

    /// Дата анализа в формате YYYY-MM-DD, если она достоверно известна.
    public let analyzeDate: String?

    /// Имя файла без директорий.
    public let fileName: String

    /// USB-путь внутри PIONEER, построенный текущей audio layout strategy.
    public let usbRelativePath: String

    /// Id цвета из справочника colors.
    public let colorId: UInt32

    /// Исходный URL аудио для копирования в выбранную audio layout strategy.
    public let sourceFileURL: URL?

    /// Создаёт трек export-модели.
    public init(
        id: UInt32,
        sourceTrackId: UUID,
        title: String,
        artist: String,
        durationSeconds: UInt32,
        sampleRate: UInt32? = nil,
        fileSize: UInt32? = nil,
        sampleDepth: UInt16? = nil,
        bitrate: UInt32? = nil,
        tempoX100: UInt32? = nil,
        analyzeDate: String? = nil,
        fileName: String,
        usbRelativePath: String,
        colorId: UInt32,
        sourceFileURL: URL? = nil
    ) {
        self.id = id
        self.sourceTrackId = sourceTrackId
        self.title = title
        self.artist = artist
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.fileSize = fileSize
        self.sampleDepth = sampleDepth
        self.bitrate = bitrate
        self.tempoX100 = tempoX100
        self.analyzeDate = analyzeDate
        self.fileName = fileName
        self.usbRelativePath = usbRelativePath
        self.colorId = colorId
        self.sourceFileURL = sourceFileURL
    }
}
