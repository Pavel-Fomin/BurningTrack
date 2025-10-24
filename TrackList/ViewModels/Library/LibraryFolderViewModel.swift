//
//  LibraryFolderViewModel.swift
//  TrackList
//
//  ViewModel для папки фонотеки: содержит секции, метаданные и имена треклистов
//
//  Created by Pavel Fomin on 08.08.2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class LibraryFolderViewModel: ObservableObject {
    let folder: LibraryFolder
    private let allowedAudioExts: Set<String> = ["mp3","flac","wav","aiff","aac","m4a","ogg"]
    private let initialParseCount = 20                     /// подберём позже (20–40)
    private var lastScannedURLs: [URL] = []                /// Сохраняем список файлов последнего скана чтобы считать tail без повторного сканирования
    private var tailWarmupTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var trackSections: [TrackSection] = []          /// Группы треков по дате
    @Published var trackListNamesByURL: [URL: [String]] = [:]  /// Соответствие: URL → [названия треклистов, в которых есть трек]
    @Published var metadataByURL: [URL: TrackMetadataCacheManager.CachedMetadata] = [:]  /// Кеш метаданных (artist, title, duration и др.)
    @Published var isLoading: Bool = false
    @Published private(set) var didLoad: Bool = false
    @Published private(set) var didLoadTrackListNames = false
    @Published var subfolders: [LibraryFolder] = []
    @Published var pendingRevealTrackURL: URL?
    @Published var revealedTrackID: UUID? = nil               /// Подсветка трека после скролла
    @Published private(set) var didStartTailWarmup = false    /// Управление хвостовой подгрузкой
    @Published var scrollTargetID: UUID? = nil                /// Цель для автопрокрутки
    
    var headCount: Int { min(initialParseCount, trackSections.flatMap { $0.tracks }.count) }  /// Для удобства в UI
    
    func loadSubfoldersIfNeeded() {
        guard subfolders.isEmpty else { return }
        subfolders = MusicLibraryManager.shared.loadSubfolders(for: folder.url)
    }
    
    private var trackListsObserver: NSObjectProtocol?
    
    init(folder: LibraryFolder) {
        self.folder = folder
        trackListsObserver = NotificationCenter.default.addObserver(
            forName: .trackListsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // замыкание синхронное → внутри создаём async‑задачу на MainActor
            Task { @MainActor [weak self] in
                self?.loadTrackListNamesByURL()
            }
            
        }
        // Сбрасываем старые подписки перед созданием новой
        cancellables.removeAll()
        
        NavigationCoordinator.shared.revealTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                guard let self else { return }
                
                // Проверяем, что это актуальная папка
                guard url.deletingLastPathComponent() == self.folder.url else { return }
                
                // Если уже обрабатывали этот reveal — пропускаем
                if self.pendingRevealTrackURL == url { return }
                self.pendingRevealTrackURL = url
                
                print("♻️ Восстанавливаем reveal-сигнал для:", url.lastPathComponent)
                
                if !self.trackSections.isEmpty {
                    self.scrollToTrackIfExists(url)
                } else {
                    print("⏳ Ожидаем загрузку секций для восстановленного сигнала...")
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        for await sections in self.$trackSections.values {
                            if !sections.isEmpty {
                                print("✅ Секции загружены (восстановление), выполняем скролл")
                                self.scrollToTrackIfExists(url)
                                break
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Если к моменту создания ViewModel уже есть активный трек — обработаем его сразу
        if let pending = NavigationCoordinator.shared.lastRevealedTrack {
            // если этот трек уже в обработке — не дублируем
            guard pendingRevealTrackURL != pending else { return }
            pendingRevealTrackURL = pending
            
            print("♻️ Восстанавливаем reveal-сигнал для:", pending.lastPathComponent)
            
            if pending.deletingLastPathComponent() == folder.url {
                if !self.trackSections.isEmpty {
                    self.scrollToTrackIfExists(pending)
                } else {
                    print("⏳ Ожидаем загрузку секций для восстановленного сигнала...")
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        for await sections in self.$trackSections.values {
                            if !sections.isEmpty {
                                print("✅ Секции загружены (восстановление), выполняем скролл")
                                self.scrollToTrackIfExists(pending)
                                break
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func scrollToTrackIfExists(_ url: URL) {
        // 1) Пытаемся найти трек сразу
        if let found = self.trackSections
            .flatMap({ $0.tracks })
            .first(where: { $0.resolvedURL == url }) {
            
            print("🎯 Найден трек, запускаем прокрутку:", found.title ?? found.url.lastPathComponent)
            self.scrollTargetID = found.id
            self.revealedTrackID = found.id
            
            // Сбрасываем подсветку через 4 сек
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                if self.revealedTrackID == found.id {
                    self.revealedTrackID = nil
                }
            }
        } else {
            // 2) Если не найден — ждём первое изменение trackSections и пробуем один раз
            print("⚠️ Трек не найден среди секций, ждём обновления...")
            Task { @MainActor [weak self] in
                guard let self else { return }
                for await sections in self.$trackSections.values {
                    if sections.flatMap({ $0.tracks }).contains(where: { $0.resolvedURL == url }) {
                        print("✅ Повторная попытка: трек найден после обновления секций")
                        self.scrollToTrackIfExists(url)
                        break
                    }
                }
            }
        }
    }
    
    
    // MARK: - Префетч артов с лимитом параллельных задач
    
    private func prefetchArtwork(urls: [URL], limit: Int = 1) {
        guard !urls.isEmpty else { return }
        Task.detached(priority: .userInitiated) {
            var i = 0
            while i < urls.count {
                let end = min(i + limit, urls.count)
                let chunk = Array(urls[i..<end])
                await withTaskGroup(of: Void.self) { group in
                    for u in chunk {
                        group.addTask { _ = await ArtworkLoader.loadIfNeeded(current: nil, url: u) }
                    }
                }
                i = end
            }
        }
    }
    
    
    // MARK: - Загружает треки из папки и группирует по дате
    
    func refresh() async {
        await refreshFastStart(firstCount: initialParseCount)
    }
    
    
    // MARK: - Быстрый старт: сначала первые N, потом остальное, со стабильным порядком
    func refreshFastStart(firstCount: Int) async {
        isLoading = true
        
        let urls = scanFolderURLs(recursive: false)
        let orderMap: [URL:Int] = Dictionary(uniqueKeysWithValues:
                                                urls.enumerated().map { ($0.element, $0.offset) }
        )
        self.lastScannedURLs = urls
        
        let head = Array(urls.prefix(firstCount))
        let tail = Array(urls.dropFirst(firstCount))
        
        // ранний префетч обложек для head
        //prefetchArtwork(urls: head, limit: 6)
        
        // показываем первые N
        let firstSections: [TrackSection] = await Task.detached(priority: .userInitiated) { [head, orderMap] in
            let tracks = await MusicLibraryManager.shared.generateLibraryTracks(from: head)
            return Self.groupTracksByDate(tracks, order: orderMap)
        }.value
        
        withAnimation(nil) {
            self.trackSections = firstSections
            self.isLoading = false
        }
        
        
        // грузим tail (треки)
        let restTracks: [LibraryTrack] = await Task.detached(priority: .utility) { [tail] in
            guard !tail.isEmpty else { return [] }
            return await MusicLibraryManager.shared.generateLibraryTracks(from: tail)
        }.value
        
        // дождались head-метаданных — пересчитываем плашки ОДИН РАЗ
        _ = headCount
        await MainActor.run { self.loadTrackListNamesByURL() }
        
        guard !restTracks.isEmpty else { return }
        
        let allTracks = firstSections.flatMap { $0.tracks } + restTracks
        let grouped = Self.groupTracksByDate(allTracks, order: orderMap)
        await MainActor.run { withAnimation(nil) { self.trackSections = grouped } }
        
        // ПРОГРЕВ МЕТАДАННЫХ ДЛЯ TAIL -> ещё один пересчёт плашек
        Task.detached { [weak self] in
            guard let self else { return }
            await MainActor.run { self.loadTrackListNamesByURL() }
        }
    }
    
    // MARK: - Загружает названия треклистов, в которых встречаются треки из этой папки
    
    func loadTrackListNamesByURL() {
        // какие URL сейчас на экране
        let urlsInView = trackSections.flatMap { $0.tracks.map { $0.url } }
        
        // 1) карты соответствий
        var namesByURL:   [URL: Set<String>] = [:]   // прямое совпадение по URL
        var namesByStrong: [String: Set<String>] = [:] // title|artist|duration
        var namesBySoft:   [String: Set<String>] = [:] // title|artist
        var namesByStem:   [String: Set<String>] = [:] // имя файла без расширения (fallback)
        
        // 2) обойдём все треклисты и заполним карты
        let metas = TrackListManager.shared.loadTrackListMetas()
        for meta in metas {
            let list = TrackListManager.shared.getTrackListById(meta.id)
            for t in list.tracks {
                namesByURL[t.url, default: []].insert(meta.name)
                
                let k = identityKeys(title: t.title, artist: t.artist, duration: t.duration)
                if !k.strong.isEmpty { namesByStrong[k.strong, default: []].insert(meta.name) }
                if !k.soft.isEmpty   { namesBySoft[k.soft,   default: []].insert(meta.name) }
                
                let stem = fileStem(t.url)
                if !stem.isEmpty     { namesByStem[stem,     default: []].insert(meta.name) }
            }
        }
        
        // 3) собираем результат для текущих URL
        var result: [URL: [String]] = [:]
        result.reserveCapacity(urlsInView.count)
        
        for url in urlsInView {
            var names = namesByURL[url] ?? []
            
            // берём теги если уже есть; иначе будем падать на stem
            let meta = metadataByURL[url]
            let title = meta?.title
            let artist = meta?.artist
            let duration = meta?.duration ?? 0
            let k = identityKeys(title: title, artist: artist, duration: duration)
            
            if let s = namesByStrong[k.strong] { names.formUnion(s) }
            if names.isEmpty, let s2 = namesBySoft[k.soft] { names.formUnion(s2) }
            
            // fallback: имя файла — работает до загрузки тегов
            let stem = fileStem(url)
            if names.isEmpty, let s3 = namesByStem[stem] { names.formUnion(s3) }
            
            result[url] = Array(names).sorted()
        }
        
        trackListNamesByURL = result
    }
    
    
    // MARK: - Ленивая загрузка треков, если ещё не были загружены
    
    func loadTracksIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await refresh()
    }
    
    
    // MARK: - Внутренние методы
    
    /// Группирует треки по дате (используется для создания секций)
    nonisolated private static func groupTracksByDate(
        _ tracks: [LibraryTrack],
        order: [URL:Int]? = nil
    ) -> [TrackSection] {
        let calendar = Calendar.current
        
        let grouped = Dictionary(grouping: tracks) { track in
            calendar.startOfDay(for: track.addedDate)
        }
        
        let days = grouped.keys.sorted(by: >)
        
        return days.map { day in
            var items = grouped[day] ?? []
            
            items.sort { a, b in
                // 1) по позиции из скана — самый стабильный вариант
                if let oa = order?[a.url], let ob = order?[b.url], oa != ob {
                    return oa < ob
                }
                // 2) иначе по дате (новее выше)
                if a.addedDate != b.addedDate { return a.addedDate > b.addedDate }
                // 3) и, на всякий, по имени файла
                return a.url.lastPathComponent.localizedCaseInsensitiveCompare(
                    b.url.lastPathComponent
                ) == .orderedAscending
            }
            
            let title: String = {
                if calendar.isDateInToday(day) { return "Сегодня" }
                if calendar.isDateInYesterday(day) { return "Вчера" }
                let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .none
                return df.string(from: day)
            }()
            
            return TrackSection(
                id: ISO8601DateFormatter().string(from: day),
                title: title,
                tracks: items
            )
        }
    }
    
    
    // MARK: - Сканирование папки (одна реализация + рекурсия)
    
    private func scanFolderURLs(recursive: Bool = false, maxDepth: Int = 1) -> [URL] {
        
        // основной вход: сканируем текущую папку viewModel'а
        return scanFolderURLs(at: folder.url, maxDepth: maxDepth, recursive: recursive)
    }
    
    private func scanFolderURLs(at root: URL, maxDepth: Int, recursive: Bool) -> [URL] {
        var result: [URL] = []
        
        let accessed = root.startAccessingSecurityScopedResource()
        defer { if accessed { root.stopAccessingSecurityScopedResource() } }
        
        do {
            let fm = FileManager.default
            let contents = try fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            var subfolders: [URL] = []
            
            for item in contents {
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                
                if isDir {
                    if recursive && maxDepth > 0 {
                        subfolders.append(item)
                    }
                } else {
                    let ext = item.pathExtension.lowercased()
                    if allowedAudioExts.contains(ext) {
                        result.append(item)
                    }
                }
            }
            
            // Уходим в подкаталоги, если рекурсия включена
            if recursive && maxDepth > 0 {
                for sub in subfolders {
                    result.append(
                        contentsOf: scanFolderURLs(at: sub, maxDepth: maxDepth - 1, recursive: true)
                    )
                }
            }
        } catch {
            print("❌ scanFolderURLs error:", error)
        }
        
        return result
    }
    
    
    // MARK: - Названия треклистов
    
    func loadTrackListNamesIfNeeded() {
        guard !didLoadTrackListNames else { return }
        didLoadTrackListNames = true
        loadTrackListNamesByURL()
    }
    
    // MARK: - Хелперы принадлежности к треклисту
    
    private func norm(_ s: String?) -> String {
        guard var t = s?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return "" }
        // убираем лишние пробелы и пунктуацию
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "[\\p{Punct}]+", with: "", options: .regularExpression)
        return t
    }
    
    // вернём два ключа: строгий (с длительностью) и мягкий (без длительности)
    private func identityKeys(title: String?, artist: String?, duration: Double?) -> (strong: String, soft: String) {
        let nt = norm(title), na = norm(artist)
        let soft = (nt.isEmpty && na.isEmpty) ? "" : "\(nt)|\(na)"
        let d = Int((duration ?? 0).rounded())
        let strong = soft.isEmpty ? "" : "\(soft)|\(d)"
        return (strong, soft)
    }
    
    private func fileStem(_ url: URL) -> String {
        norm(url.deletingPathExtension().lastPathComponent)
    }
    
    func setMetadata(_ meta: TrackMetadataCacheManager.CachedMetadata, for url: URL) {
        metadataByURL[url] = meta
        loadTrackListNamesByURL()   // теги появились → пересчитываем плашки
    }
    
    deinit {
        // Отписываемся от всех Combine-подписок (revealTrack и др.)
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        // Убираем наблюдатель изменений треклистов
        if let o = trackListsObserver {
            NotificationCenter.default.removeObserver(o)
        }
        print("🧹 LibraryFolderViewModel освобождён для:", folder.name)
    }
}

