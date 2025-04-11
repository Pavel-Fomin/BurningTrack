import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct AudioTrack: Identifiable {
    let id = UUID()
    let url: URL
    var progress: Double = 0.0
    var artist: String = "Неизвестен"
    var title: String = "Без названия"
    var duration: TimeInterval = 0
    var artwork: UIImage? = nil
}

struct ContentView: View {
    @State private var tracks: [AudioTrack] = []
    @State private var importedTracks: [AudioTrack] = []
    @State private var exportFolder: URL?
    @State private var isDocumentPickerPresented = false
    @State private var isImporting = false
    @State private var player: AVPlayer = AVPlayer()
    @State private var isPlaying: Bool = false
    @State private var currentTrack: AudioTrack?

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ Audio session configured for playback.")
        } catch {
            print("❌ Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(tracks) { track in
                    TrackRowView(track: track)
                        .onTapGesture {
                            if currentTrack?.id == track.id {
                                togglePlayPause()
                            } else {
                                play(track: track)
                            }
                        }
                }
                ForEach(importedTracks) { track in
                    TrackRowView(track: track)
                        .onTapGesture {
                            if currentTrack?.id == track.id {
                                togglePlayPause()
                            } else {
                                play(track: track)
                            }
                        }
                }
            }
            .navigationTitle("TRACKLIST")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            isImporting = true
                        }) {
                            Image(systemName: "plus")
                        }
                        Button(action: {
                            isDocumentPickerPresented.toggle()
                        }) {
                            Image(systemName: "record.circle")
                        }
                    }
                }
            }
            
            if let track = currentTrack {
                VStack {
                    Spacer()
                    HStack {
                        if let artwork = track.artwork {
                            Image(uiImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .cornerRadius(4)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 44, height: 44)
                                .cornerRadius(4)
                        }

                        VStack(alignment: .leading) {
                            Text(track.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button(action: {
                            togglePlayPause()
                        }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(radius: 3)
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom))
                }
                .animation(.easeInOut, value: currentTrack?.id)
            }
        }
        .onAppear {
            configureAudioSession()
        }
        .ignoresSafeArea()
        .sheet(isPresented: $isDocumentPickerPresented) {
            DocumentPickerView { selectedURL in
                exportFolder = selectedURL
                exportTracks()
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                DispatchQueue.global(qos: .userInitiated).async {
                    for url in urls {
                        print("Импортирован: \(url)")

                        guard url.startAccessingSecurityScopedResource() else {
                            print("❌ Не удалось получить доступ к ресурсу")
                            continue
                        }
                        defer { url.stopAccessingSecurityScopedResource() }

                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)

                        do {
                            if FileManager.default.fileExists(atPath: tempURL.path) {
                                try FileManager.default.removeItem(at: tempURL)
                            }
                            try FileManager.default.copyItem(at: url, to: tempURL)
                            print("✅ Скопирован во временную директорию: \(tempURL)")

                            let asset = AVURLAsset(url: tempURL)
                            let duration = CMTimeGetSeconds(asset.duration)
                            let newTrack = AudioTrack(url: tempURL, duration: duration)

                            DispatchQueue.main.async {
                                importedTracks.append(newTrack)
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

    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func exportTracks() {
        guard let folder = exportFolder else { return }

        for (index, track) in tracks.enumerated() {
            let destinationURL = folder.appendingPathComponent(track.url.lastPathComponent, isDirectory: false)

            do {
                let data = try Data(contentsOf: track.url)
                try data.write(to: destinationURL)

                DispatchQueue.main.async {
                    tracks[index].progress = 1.0
                }
            } catch {
                print("Ошибка копирования файла: \(error)")
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
    }

    func previousTrack() {
        // Implementation of previous track functionality
    }

    func nextTrack() {
        // Implementation of next track functionality
    }
}

struct DocumentPickerView: View {
    var onPick: (URL) -> Void

    var body: some View {
        DocumentPickerRepresentable(onPick: onPick)
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

    var body: some View {
        HStack {
            Text(track.title)
                .font(.headline)
            Spacer()
            Text(track.artist)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}
