import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import MediaPlayer
import AVKit

func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

struct ExportPickerView: UIViewControllerRepresentable {
    let fileURLs: [URL]

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: fileURLs, asCopy: true)
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
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
    var isExporting: Bool = false // 🔄 Добавили флаг экспорта

}

struct ContentView: View {
    @Environment(\.editMode) private var editMode
    @State private var tracks: [AudioTrack] = []
    @State private var exportProgress: (completed: Int, total: Int)? = nil
    @State private var exportFolder: URL?
    @State private var exportFileURLs: [URL] = []
    @State private var isDocumentPickerPresented = false
    @State private var isFolderPickerPresented = false
    @State private var isImporting = false
    @State private var player: AVPlayer = AVPlayer()
    @State private var isPlaying: Bool = false
    @State private var currentTrack: AudioTrack?
    @State private var currentTime: Double = 0
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isExportCancelled: Bool = false
    
    private func addPeriodicTimeObserver() {
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        _ = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds
        }
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            print("✅ Audio session configured for playback.")
        } catch {
            print("❌ Failed to configure audio session: \(error.localizedDescription)")
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
            player.seek(to: CMTime(seconds: positionEvent.positionTime, preferredTimescale: 600))
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
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = track.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        if let artworkImage = track.artwork {
            let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in artworkImage }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                if let progress = exportProgress {
                    VStack(alignment: .leading, spacing: 6) {
                        if progress.completed < progress.total {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Записано \(progress.completed) из \(progress.total)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    ProgressView(value: Float(progress.completed), total: Float(progress.total))
                                        .progressViewStyle(LinearProgressViewStyle())
                                }
                                Spacer()
                                Button(action: {
                                    isExportCancelled = true
                                    exportProgress = nil  // Очистить прогресс
                                    print("⛔️ Экспорт прерван пользователем")
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .imageScale(.medium)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            HStack {
                                Text("✅ Копирование \(progress.total) завершено")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Spacer()
                                Button("Закрыть") {
                                    exportProgress = nil
                                }
                                .font(.caption)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal)
                }
                List {
                    ForEach(tracks) { track in
                        TrackRowView(track: track, isPlaying: isPlaying, isCurrent: currentTrack?.id == track.id)
                            .id(track.id)
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
                .onAppear {
                    scrollProxy = proxy
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("TRACKLIST")
                        .font(.headline)
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        print("⚠️ Очистка треков")
                        tracks.removeAll()
                    }) {
                        Image(systemName: "wand.and.sparkles")
                    }

                    Button(action: {
                        isFolderPickerPresented = true
                    }) {
                        Image(systemName: "laser.burst")
                    }

                    Button(action: {
                        isImporting = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
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
                            if let track = currentTrack {
                                withAnimation {
                                    scrollProxy?.scrollTo(track.id, anchor: .center)
                                }
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
                        Text(formatDuration(currentTime))
                            .font(.caption)
                            .foregroundColor(.gray)
 
                        Slider(value: Binding(
                            get: { currentTime },
                            set: { newValue in
                                player.seek(to: CMTime(seconds: newValue, preferredTimescale: 600))
                            }
                        ), in: 0...track.duration)
 
                        Text(formatDuration(max(0, track.duration - currentTime)))
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
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .shadow(radius: 3)
                .padding(.horizontal)
                .transition(.move(edge: .bottom))
                .animation(.easeInOut, value: currentTrack?.id)
            }
        }
        .onAppear {
            configureAudioSession()
            setupRemoteCommandCenter()
            addPeriodicTimeObserver()
        }
        .ignoresSafeArea()
        .sheet(isPresented: $isFolderPickerPresented) {
            DocumentPickerView { folder in
                exportTracks(to: folder)
            }
        }
        .sheet(isPresented: $isDocumentPickerPresented) {
            ExportPickerView(fileURLs: exportFileURLs)
        }
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
                            print("❌ Не удалось получить доступ к ресурсу")
                            continue
                        }
                        defer { url.stopAccessingSecurityScopedResource() }

                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                        if tracks.contains(where: { $0.filename == tempURL.deletingPathExtension().lastPathComponent }) {
                            print("⚠️ Трек уже существует в списке: \(tempURL.lastPathComponent)")
                            continue
                        }

                        do {
                            if FileManager.default.fileExists(atPath: tempURL.path) {
                                try FileManager.default.removeItem(at: tempURL)
                            }
                            try FileManager.default.copyItem(at: url, to: tempURL)
                            print("✅ Скопирован во временную директорию: \(tempURL)")

                            let asset = AVURLAsset(url: tempURL)
                            print("🧪 asset.duration.seconds = \(asset.duration.seconds)")
                            var duration = CMTimeGetSeconds(asset.duration)
                            if duration == 0 {
                                let audioFile = try AVAudioFile(forReading: tempURL)
                                print("🧪 AVAudioFile fallback duration: \(Double(audioFile.length) / audioFile.fileFormat.sampleRate)")
                                duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
                            }
                            let filename = tempURL.deletingPathExtension().lastPathComponent
                            var trackTitle: String? = nil
                            if let metadataTitle = asset.commonMetadata.first(where: { $0.commonKey?.rawValue == "title" })?.stringValue {
                                if metadataTitle != filename {
                                    trackTitle = metadataTitle
                                }
                            }
                            var artist: String? = nil
                            if let metadataArtist = asset.commonMetadata.first(where: { $0.commonKey?.rawValue == "artist" })?.stringValue {
                                artist = metadataArtist
                            }
                            var artworkImage: UIImage? = nil
                            if let artworkData = AVMetadataItem.metadataItems(
                                from: asset.commonMetadata,
                                withKey: AVMetadataKey.commonKeyArtwork,
                                keySpace: .common
                            ).first?.dataValue {
                                artworkImage = UIImage(data: artworkData)
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

    func exportTracks(to folder: URL) {
        DispatchQueue.global(qos: .utility).async {
            guard folder.startAccessingSecurityScopedResource() else {
                print("❌ Не удалось получить доступ к папке для экспорта")
                return
            }
            defer { folder.stopAccessingSecurityScopedResource() }

            print("🚀 Начинаем экспорт в: \(folder)")
            print("🎵 Треков для записи: \(tracks.count)")

            let semaphore = DispatchSemaphore(value: 1)
            let sortedTracks = tracks // фиксируем порядок
            DispatchQueue.main.async {
                exportProgress = (0, sortedTracks.count)
            }
            DispatchQueue.main.async {
                exportProgress = (0, sortedTracks.count)
            }

            for (index, track) in sortedTracks.enumerated() {
                if isExportCancelled {
                    print("⛔️ Экспорт остановлен")
                    break
                }
                semaphore.wait()

                let indexString = String(format: "%02d", index + 1)
                let originalExtension = track.url.pathExtension
                let originalName = track.url.deletingPathExtension().lastPathComponent
                let prefixedName = "\(indexString)_\(originalName).\(originalExtension)"
                let destinationURL = folder.appendingPathComponent(prefixedName)

                DispatchQueue.global().async {
                    do {
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            do {
                                try FileManager.default.removeItem(at: destinationURL)
                                print("🧹 Удалён старый файл: \(destinationURL.lastPathComponent)")
                            } catch {
                                print("❌ Не удалось удалить старый файл: \(error.localizedDescription)")
                            }
                            Thread.sleep(forTimeInterval: 0.05)
                        }

                        let data = try Data(contentsOf: track.url)
                        try data.write(to: destinationURL)

                        DispatchQueue.main.async {
                            if let i = tracks.firstIndex(where: { $0.id == track.id }) {
                                tracks[i].progress = 1.0
                                exportProgress?.completed += 1
                            }
                        }

                    } catch {
                        print("❌ Ошибка при записи трека \(track.filename): \(error.localizedDescription)")
                    }

                    semaphore.signal()
                }

                Thread.sleep(forTimeInterval: 0.2)
            }

            DispatchQueue.main.async {
                print("✅ Все треки экспортированы.")
                isExportCancelled = false
            }
        }
    }
    

    func play(track: AudioTrack) {
        print("\n🔊 Попытка воспроизведения трека:")
        print("URL: \(track.url)")
        print("Файл существует: \(FileManager.default.fileExists(atPath: track.url.path))")

        let asset = AVURLAsset(url: track.url)

        Task {
            do {
                let isPlayable = try await asset.load(.isPlayable)
                guard isPlayable else {
                    print("❌ Файл не поддерживается")
                    return
                }
                print("✅ Файл можно воспроизвести")
                let playerItem = AVPlayerItem(asset: asset)
                DispatchQueue.main.async {
                    player.replaceCurrentItem(with: playerItem)
                    player.play()
                    currentTrack = track
                    isPlaying = true
                    updateNowPlayingInfo(for: track)
                }
            } catch {
                print("❌ Не удалось загрузить/воспроизвести трек: \(error.localizedDescription)")
            }
        }
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
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
        // Play the previous track
        play(track: previous)
    }
}

struct DocumentPickerView: View {
    var onPick: (URL) -> Void

    var body: some View {
        DocumentPickerRepresentable { url in
            print("📁 Выбрана папка: \(url)")
            onPick(url)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct DocumentPickerRepresentable: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
        documentPicker.delegate = context.coordinator
        return documentPicker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first, url.startAccessingSecurityScopedResource() {
                onPick(url)
                url.stopAccessingSecurityScopedResource()
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Handle cancellation if needed
        }
    }
}

struct TrackRowView: View {
    let track: AudioTrack
    let isPlaying: Bool
    let isCurrent: Bool

    var body: some View {
        ZStack {
            if isCurrent {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.12))
                    .padding(.horizontal, -8)
            }
            HStack(spacing: 12) {
                ZStack {
                    if let artwork = track.artwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
 
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
                .cornerRadius(4)
 
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.artist ?? track.filename)
                        .font(.subheadline)
                        .foregroundColor(.primary)
 
                    HStack {
                        Text(track.title ?? "")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        Spacer()
                        Text(formatDuration(track.duration))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
        }
    }
}
struct AVRoutePickerViewRepresented: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.activeTintColor = .systemBlue
        view.tintColor = .gray
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
