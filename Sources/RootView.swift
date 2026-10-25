import SwiftUI

let audioExtensions: Set<String> = ["mp3", "m4a", "wav", "flac", "aac", "aiff", "m4b", "caf"]

struct RootView: View {
    @EnvironmentObject var player: PlayerModel
    @State private var showPicker = false
    @State private var files: [URL] = []
    @State private var folderName = ""
    @State private var message = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showPicker = true
                    } label: {
                        Label("选择文件夹", systemImage: "folder.badge.plus")
                    }
                    if !folderName.isEmpty {
                        Text("当前：\(folderName)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if !message.isEmpty {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if !files.isEmpty {
                    Section("音频（\(files.count)）") {
                        ForEach(Array(files.enumerated()), id: \.offset) { idx, url in
                            Button {
                                player.open(url: url)
                            } label: {
                                HStack {
                                    Text("\(idx + 1). \(url.deletingPathExtension().lastPathComponent)")
                                        .lineLimit(1)
                                    Spacer()
                                    if player.title == url.deletingPathExtension().lastPathComponent {
                                        Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("本地听书")
            .sheet(isPresented: $showPicker) {
                FolderPicker { url in
                    showPicker = false
                    loadFolder(url)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if player.title != "未播放" {
                    PlayerBar()
                }
            }
            .task { restoreFolder() }
        }
    }

    private func loadFolder(_ url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        do {
            let items = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            files = items
                .filter { audioExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            folderName = url.lastPathComponent
            message = ""
            if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(data, forKey: "folderBookmark")
            }
        } catch {
            message = "读取失败：\(error.localizedDescription)"
        }
    }

    private func restoreFolder() {
        guard let data = UserDefaults.standard.data(forKey: "folderBookmark") else { return }
        var stale = false
        if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) {
            loadFolder(url)
        }
    }
}

struct PlayerBar: View {
    @EnvironmentObject var player: PlayerModel

    var body: some View {
        VStack(spacing: 6) {
            if player.duration > 0 {
                Slider(
                    value: Binding(
                        get: { player.current },
                        set: { player.seek(to: $0) }
                    ),
                    in: 0...max(player.duration, 1)
                )
            }
            HStack {
                Text(player.title).font(.footnote).lineLimit(1)
                Spacer()
                Button {
                    player.toggle()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}
