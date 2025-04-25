import AVFoundation
import Combine
// Класс для управления AVPlayer и отслеживания времени воспроизведения
class PlayerManager: ObservableObject {
    @Published var currentTime: TimeInterval = 0.0
    @Published var trackDuration: TimeInterval = 0.0
    var player: AVPlayer
    private var timeObserverToken: Any?

    init(player: AVPlayer) {
        self.player = player
        addPeriodicTimeObserver()
    }

    deinit {
        removePeriodicTimeObserver()
    }

    private func addPeriodicTimeObserver() {
        removePeriodicTimeObserver()
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            if let currentItem = self.player.currentItem {
                // trackDuration больше НЕ пересчитываем тут — используем setDuration() из play(track:)
                self.currentTime = currentItem.currentTime().seconds
            }
        }
    }

    private func removePeriodicTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    func setDuration(_ duration: TimeInterval) {
        self.trackDuration = duration
    }

}
// Форматирование времени для миниплеера (MM:SS)
func formatTimeSimple(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%02d:%02d", minutes, seconds)
}
import SwiftUI
import UniformTypeIdentifiers
import MediaPlayer
import AVKit

func formatTotalDuration(_ duration: TimeInterval) -> String {
    let totalMinutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    let days = hours / 24
    let remainingHours = hours % 24

    if days > 0 {
        return String(format: "%dд:%02dч:%02dм", days, remainingHours, minutes)
    } else if hours > 0 {
        return String(format: "%02dч:%02dм", hours, minutes)
    } else {
        return "\(minutes) минут"
    }
}
func exportTracks(_ urls: [URL]) {
    // Только сортированные треки — по имени с префиксами
    _ = urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })

}

struct AudioTrack: Identifiable {
    let id = UUID()
    let url: URL
    var progress: Double = 0.0
    var artist: String?
    var title: String?
    var filename: String
    var duration: TimeInterval = 0
    var artwork: UIImage? = nil
    var isExporting: Bool = false //  Добавили флаг экспорта
}


struct ContentView: View {
    @Environment(\.editMode) private var editMode
    @State private var tracks: [AudioTrack]
    init(tracks: [AudioTrack] = []) {
        _tracks = State(initialValue: tracks)
    }
    // System export
    @State private var exportFileURLs: [URL] = []
    @State private var isDocumentPickerPresented = false
    @State private var isImporting = false
    @StateObject private var playerManager = PlayerManager(player: AVPlayer())
    @State private var isPlaying: Bool = false
    @State var currentTrack: AudioTrack?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isExportCancelled: Bool = false
    @State private var isShowingURLList = false
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            print("Audio session configured for playback.")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { _ in
            togglePlayPause()
            return .success
        }

        commandCenter.pauseCommand.addTarget { _ in
            togglePlayPause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { _ in
            nextTrack()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { _ in
            previousTrack()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            playerManager.player.seek(to: CMTime(seconds: positionEvent.positionTime, preferredTimescale: 600))
            return .success
        }

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
    }

    func updateNowPlayingInfo(for track: AudioTrack) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerManager.currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = track.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        if let artworkImage = track.artwork {
            let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in artworkImage }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(tracks) { track in
                        TrackRowView(track: track, isPlaying: isPlaying, isCurrent: currentTrack?.id == track.id)
                            .id(track.id)
                            .listRowBackground(
                                currentTrack?.id == track.id
                                ? (colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.12))
                                : Color.clear
                            )
                            .onTapGesture {
                                if currentTrack?.id == track.id {
                                    togglePlayPause()
                                } else {
                                    play(track: track)
                                }
                            }
                    }
                    .onMove { indices, newOffset in
                        tracks.move(fromOffsets: indices, toOffset: newOffset)
                    }
                    .onDelete { indexSet in
                        tracks.remove(atOffsets: indexSet)
                    }
                }
                .listStyle(.plain)
                .onAppear {
                    scrollProxy = proxy
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TRACKLIST")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !tracks.isEmpty {
                            Text("Треков: \(tracks.count) • \(formatTotalDuration(tracks.reduce(0) { $0 + $1.duration }))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.bottom, 12) // паддинг хедера
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        print("Очистка треков")
                        tracks.removeAll()
                    }) {
                        Image(systemName: "wand.and.sparkles")
                    }

                    Button {
                        let exportedTracks = tracks.enumerated().compactMap { index, track -> (from: URL, name: String)? in
                            let prefix = String(format: "%02d", index + 1)
                            let ext = track.url.pathExtension
                            let base = track.url.deletingPathExtension().lastPathComponent
                            let filename = "\(prefix)_\(base).\(ext)"
                            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                            do {
                                if FileManager.default.fileExists(atPath: tempURL.path) {
                                    try FileManager.default.removeItem(at: tempURL)
                                }
                                try FileManager.default.copyItem(at: track.url, to: tempURL)
                                return (from: tempURL, name: filename)
                            } catch {
                                print("Ошибка при подготовке \(filename): \(error)")
                                return nil
                            }
                        }

                        let picker = UIDocumentPickerViewController(forExporting: exportedTracks.map { $0.from }, asCopy: true)
                        picker.delegate = ExportFolderPicker(tracksToExport: exportedTracks)
                        picker.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                        picker.allowsMultipleSelection = false
                        picker.shouldShowFileExtensions = true

                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = scene.windows.first?.rootViewController {
                            rootVC.present(picker, animated: true, completion: nil)
                        }
                    } label: {
                        Image(systemName: "laser.burst")
                    }

                    Button(action: {
                        isImporting = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let track = currentTrack {
                    VStack(spacing: 8) {
                        HStack {
                            if let artwork = track.artwork {
                                Image(uiImage: artwork)
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(width: 44, height: 44)
                                    .cornerRadius(4)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 44, height: 44)
                                    .cornerRadius(4)
                            }

                            Button(action: {
                                withAnimation {
                                    scrollProxy?.scrollTo(track.id, anchor: .center)
                                }
                            }) {
                                VStack(alignment: .leading) {
                                    Text(track.artist ?? track.filename)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    if let title = track.title {
                                        Text(title)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            AVRoutePickerViewRepresented()
                                .frame(width: 24, height: 24)
                        }

                        HStack {
                            Text(formatTimeSimple(playerManager.currentTime))
                                .font(.caption)
                                .foregroundColor(.gray)

                            Slider(value: Binding(
                                get: { playerManager.currentTime },
                                set: { newValue in
                                    playerManager.player.seek(to: CMTime(seconds: newValue, preferredTimescale: 600))
                                    playerManager.currentTime = newValue
                                    if let currentTrack = currentTrack {
                                        updateNowPlayingInfo(for: currentTrack)
                                    }
                                }
                            ), in: 0...track.duration)

                            Text(formatTimeSimple(max(0, track.duration - playerManager.currentTime)))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        HStack(spacing: 32) {
                            Button(action: previousTrack) {
                                Image(systemName: "backward.fill")
                                    .font(.title2)
                            }

                            Button(action: togglePlayPause) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title2)
                            }

                            Button(action: nextTrack) {
                                Image(systemName: "forward.fill")
                                    .font(.title2)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .cornerRadius(12)
                    .shadow(radius: 3)
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            configureAudioSession()
            setupRemoteCommandCenter()
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: nil,
                queue: .main
            ) { _ in
                nextTrack()
            }
        }
        .ignoresSafeArea()
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task {
                    for url in urls {
                        print("Импортирован: \(url)")

                        guard url.startAccessingSecurityScopedResource() else {
                            print("Не удалось получить доступ к ресурсу")
                            continue
                        }
                        defer { url.stopAccessingSecurityScopedResource() }

                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                        if tracks.contains(where: { $0.filename == tempURL.deletingPathExtension().lastPathComponent }) {
                            print("Трек уже существует в списке: \(tempURL.lastPathComponent)")
                            continue
                        }

                        do {
                            if FileManager.default.fileExists(atPath: tempURL.path) {
                                try FileManager.default.removeItem(at: tempURL)
                            }
                            try FileManager.default.copyItem(at: url, to: tempURL)
                            print("Скопирован во временную директорию: \(tempURL)")

                            let asset = AVURLAsset(url: tempURL)
                            let audioFile = try AVAudioFile(forReading: tempURL)
                            // === Сравнение методов подсчёта времени ===
                            let durationAsset = asset.duration.seconds
                            let durationAudioFile = Double(audioFile.length) / audioFile.fileFormat.sampleRate
                            let difference = abs(durationAsset - durationAudioFile)
                            print("=== Проверка длительности ===")
                            print("AVAsset duration: \(durationAsset)")
                            print("AVAudioFile duration: \(durationAudioFile)")
                            print("Разница: \(difference) секунд")
                            print("=============================")
                            // === Конец вставки сравнения ===
                            let duration = durationAudioFile
                            let filename = tempURL.deletingPathExtension().lastPathComponent
                            var artist: String? = nil
                            var trackTitle: String? = nil
                            var artworkImage: UIImage? = nil

                            // Пробуем AVFoundation, как раньше:
                            if let metadataArtist = asset.commonMetadata.first(where: { $0.commonKey?.rawValue == "artist" })?.stringValue {
                                artist = metadataArtist
                            }
                            if let metadataTitle = asset.commonMetadata.first(where: { $0.commonKey?.rawValue == "title" })?.stringValue {
                                trackTitle = metadataTitle
                            }
                            if let artworkData = AVMetadataItem.metadataItems(
                                from: asset.commonMetadata,
                                withKey: AVMetadataKey.commonKeyArtwork,
                                keySpace: .common
                            ).first?.dataValue {
                                artworkImage = UIImage(data: artworkData)
                            }

                            // Если artist или trackTitle не нашлись — подключаем парсер:
                            if artist == nil || trackTitle == nil || artworkImage == nil {
                                do {
                                    let parsed = try MetadataParser.parseMetadata(from: tempURL)
                                    artist = artist ?? parsed.artist
                                    trackTitle = trackTitle ?? parsed.title ?? filename
                                    
                                    print("После парсинга: artist = \(artist ?? "nil"), title = \(trackTitle ?? "nil"), filename = \(filename)")
                                    
                                    if artworkImage == nil, let data = parsed.artworkData {
                                        artworkImage = UIImage(data: data)
                                    }
                                } catch {
                                    print("Ошибка парсинга метаданных: \(error)")
                                    print("artist: \(artist ?? "nil")")
                                    print("title: \(trackTitle ?? "nil")")
                                    print("filename: \(filename)")
                                
                                }
                            }
                            let newTrack = AudioTrack(
                                url: tempURL,
                                progress: 0.0,
                                artist: artist,
                                title: trackTitle,
                                filename: filename,
                                duration: duration,
                                artwork: artworkImage
                            )

                            DispatchQueue.main.async {
                                tracks.append(newTrack)
                            }
                        } catch {
                            print("Ошибка копирования во временную директорию: \(error)")
                        }
                    }
                }
            case .failure(let error):
                print("Ошибка импорта: \(error.localizedDescription)")
            }
        }
    }


    func play(track: AudioTrack) {
        print("\n Попытка воспроизведения трека:")
        print("URL: \(track.url)")
        print("Файл существует: \(FileManager.default.fileExists(atPath: track.url.path))")

        let asset = AVURLAsset(url: track.url)

        Task {
            do {
                let isPlayable = try await asset.load(.isPlayable)
                guard isPlayable else {
                    print("Файл не поддерживается")
                    return
                }
                print("Файл можно воспроизвести")
                let playerItem = AVPlayerItem(asset: asset)
                print("AVPlayerItem duration (ignored for FLAC): \(track.duration)")
                print("AudioTrack duration: \(track.duration)")
                DispatchQueue.main.async {
                    playerManager.player.pause()
                    isPlaying = false
                    playerManager.player.seek(to: .zero)
                    playerManager.currentTime = 0.0
                    playerManager.setDuration(track.duration)
                    if let current = currentTrack {
                        updateNowPlayingInfo(for: current)
                    }
                    playerManager.player.replaceCurrentItem(with: playerItem)
                    playerManager.player.seek(to: .zero)
                    playerManager.currentTime = 0.0
                    playerManager.setDuration(track.duration)
                    if let current = currentTrack {
                        updateNowPlayingInfo(for: current)
                    }
                    playerManager.player.play()
                    currentTrack = track
                    isPlaying = true
                    updateNowPlayingInfo(for: track)
                }
            } catch {
                print("Не удалось загрузить/воспроизвести трек: \(error.localizedDescription)")
            }
        }
    }

    func togglePlayPause() {
        if isPlaying {
            playerManager.player.pause()
            isPlaying = false
        } else {
            playerManager.player.play()
            isPlaying = true
        }
        if let track = currentTrack {
            updateNowPlayingInfo(for: track)
        }
    }

    // Function to play the next track in the playlist
    func nextTrack() {
        // Create a playlist by concatenating the two track arrays in user-defined order
        let playlist = tracks
        // Ensure the playlist is not empty and the current track exists
        guard !playlist.isEmpty, let current = currentTrack,
              let currentIndex = playlist.firstIndex(where: { $0.id == current.id }) else {
            return
        }
        // Calculate the next track index with wrap-around
        let nextIndex = (currentIndex + 1) % playlist.count
        let next = playlist[nextIndex]
        playerManager.player.pause()
        isPlaying = false
        // currentTime = 0
        // Play the next track
        play(track: next)
    }

    // Function to play the previous track in the playlist
    func previousTrack() {
        // Create a playlist by concatenating the two track arrays in user-defined order
        let playlist = tracks
        // Ensure the playlist is not empty and the current track exists
        guard !playlist.isEmpty, let current = currentTrack,
              let currentIndex = playlist.firstIndex(where: { $0.id == current.id }) else {
            return
        }
        // Calculate the previous track index with wrap-around
        let prevIndex = (currentIndex - 1 + playlist.count) % playlist.count
        let previous = playlist[prevIndex]
        playerManager.player.pause()
        isPlaying = false
        // currentTime = 0
        if let current = currentTrack {
            updateNowPlayingInfo(for: current)
        }
        // Play the previous track
        play(track: previous)
    }
}




// === TrackRowView: строка трека в списке ===
struct TrackRowView: View {
    let track: AudioTrack
    let isPlaying: Bool
    let isCurrent: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        // Основной контент строки: обложка + информация о треке
        HStack(spacing: 12) {
            // === Артворк (обложка трека) ===
            ZStack {
                if let artwork = track.artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }

                // Анимация для активного трека
                if isPlaying && isCurrent {
                    if #available(iOS 17.0, *) {
                        Image(systemName: "waveform")
                            .symbolEffect(.pulse, isActive: true)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())

                        if track.isExporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .frame(width: 20, height: 20)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    } else {
                        Image(systemName: "waveform")
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
            }
            .frame(width: 44, height: 44)
            .cornerRadius(8)

            // === Информация о треке: артист, название, длительность ===
            VStack(alignment: .leading, spacing: 2) {
                if let artist = track.artist, let title = track.title, !artist.isEmpty, !title.isEmpty {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundColor(
                            isCurrent
                            ? (colorScheme == .dark ? .white : .black)
                            : .primary
                        )

                    HStack {
                        Text(title)
                            .font(.subheadline)
                            .foregroundColor(
                                isCurrent
                                ? (colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                                : .gray
                            )
                            .lineLimit(1)
                        Spacer()
                        Text(formatTimeSimple(track.duration))
                            .font(.caption)
                            .foregroundColor(
                                isCurrent
                                ? (colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                                : .gray
                            )
                    }
                } else {
                    Text(track.filename)
                        .font(.subheadline)
                        .foregroundColor(
                            isCurrent
                            ? (colorScheme == .dark ? .white : .black)
                            : .primary
                        )

                    HStack {
                        Spacer()
                        Text(formatTimeSimple(track.duration))
                            .font(.caption)
                            .foregroundColor(
                                isCurrent
                                ? (colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                                : .gray
                            )
                    }
                }
            }
        }
        .frame(height: 48) // ← Фиксированная высота строки
    }
}
// MARK: – AirPlay Route Picker
struct AVRoutePickerViewRepresented: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.activeTintColor = .systemBlue
        view.tintColor = .gray
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // no-op
    }
}

// Новый класс ExportFolderPicker для экспорта треков в выбранную папку
class ExportFolderPicker: NSObject, UIDocumentPickerDelegate {
    let tracksToExport: [(from: URL, name: String)]

    init(tracksToExport: [(from: URL, name: String)]) {
        self.tracksToExport = tracksToExport
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let folderURL = urls.first else { return }
        guard folderURL.startAccessingSecurityScopedResource() else {
            print("Не удалось получить доступ к папке")
            return
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        for (from, name) in tracksToExport {
            let destination = folderURL.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }
            do {
                try FileManager.default.copyItem(at: from, to: destination)
                print("\(name) экспортирован")
            } catch {
                print("Ошибка экспорта \(name): \(error)")
            }
        }
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView(tracks: AudioTrack.mockList)
                .previewDevice("iPhone 15 Pro")
                .preferredColorScheme(.light)
            ContentView(tracks: AudioTrack.mockList)
                .previewDevice("iPhone 15 Pro")
                .preferredColorScheme(.dark)
        }
    }
}
