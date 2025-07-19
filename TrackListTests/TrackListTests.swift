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
    @State private var exportFolder: URL?
    @State private var isDocumentPickerPresented = false
    @State private var isImporting = false
    @State private var player: AVPlayer = AVPlayer()
    @State private var isPlaying: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if tracks.isEmpty {
                        Text("Список треков пуст. Нажмите + чтобы добавить.")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(tracks) { track in
                            Button(action: {
                                print("Tapped track: \(track.title)")
                                play(track: track)
                            }) {
                                HStack {
                                    if let image = track.artwork {
                                        Image(uiImage: image)
                                            .resizable()
                                            .frame(width: 50, height: 50)
                                            .cornerRadius(4)
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray)
                                            .frame(width: 50, height: 50)
                                            .cornerRadius(4)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(track.artist)
                                            .font(.headline)
                                        HStack {
                                            Text(track.title)
                                                .font(.subheadline)
                                            Spacer()
                                            Text(formatDuration(track.duration))
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
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
        }
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
                for url in urls {
                    print("Импортирован: \(url)")
                    tracks.append(AudioTrack(url: url))
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
        let playerItem = AVPlayerItem(url: track.url)
        player.replaceCurrentItem(with: playerItem)
        player.play()
        isPlaying = true
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
