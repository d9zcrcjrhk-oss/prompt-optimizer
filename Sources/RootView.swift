import SwiftUI
import UniformTypeIdentifiers

let audioExtensions: Set<String> = ["mp3", "m4a", "wav", "flac", "aac", "aiff", "m4b", "caf", "mp4", "ogg", "opus", "wma"]

struct RootView: View {
    @EnvironmentObject var player: PlayerModel
    @State private var showFolderPicker = false
    @State private var showFilePicker = false
    @State private var files: [URL] = []
    @State private var folderName = ""
    @State private var message = ""

    var body: some View {
        NavigationStack {
            List {
                Section("导入音频") {
                    Button {
                        showFolderPicker = true
                    } label: {
                        Label("导入整个文件夹", systemImage: "folder.badge.plus")
                    }
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("选择音频文件（可多选）", systemImage: "music.note.list")
                    }
                    Button {
                        scanAppDocuments()
                    } label: {
                        Label("扫描 App 内的「本地听书」文件夹", systemImage: "folder")
                    }
                    if !folderName.isEmpty {
                        Text(folderName).font(.footnote).foregroundStyle(.secondary)
                    }
                    if !message.isEmpty {
                        Text(message).font(.footnote).foregroundStyle(.red)
                    }
                }

                if !files.isEmpty {
                    Section("音频（\(files.count) 个）") {
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
                } else {
                    Section {
                        Text("还没有音频。点上面任一方式导入。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("本地听书")
            .sheet(isPresented: $showFolderPicker) {
                FolderPicker { url in
                    showFolderPicker = false
                    loadFolder(url)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls): loadSelectedFiles(urls)
                case .failure(let err): message = "选择文件失败：\(err.localizedDescription)"
                }
            }
            .safeAreaInset(edge: .bottom) {
                if player.title != "未播放" {
                    PlayerBar()
                }
            }
            .task { restore() }
        }
    }

    private func loadFolder(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            message = "无法访问该文件夹（权限不足）"
            return
        }
        do {
            let items = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            let audio = items
                .filter { audioExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            if audio.isEmpty {
                message = "该文件夹里没找到音频文件"
                return
            }
            files = audio
            folderName = "\(url.lastPathComponent)（\(files.count) 个）"
            message = ""
            if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(data, forKey: "folderBookmark")
                UserDefaults.standard.removeObject(forKey: "fileBookmarks")
            }
        } catch {
            message = "读取失败：\(error.localizedDescription)"
        }
    }

    private func loadSelectedFiles(_ urls: [URL]) {
        var ok: [URL] = []
        var bookmarks: [Data] = []
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            ok.append(url)
            if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                bookmarks.append(data)
            }
        }
        if ok.isEmpty {
            message = "没有可读取的音频（权限不足）"
            return
        }
        files = ok.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        folderName = "已选文件（\(files.count) 个）"
        message = ""
        UserDefaults.standard.set(bookmarks, forKey: "fileBookmarks")
        UserDefaults.standard.removeObject(forKey: "folderBookmark")
    }

    private func scanAppDocuments() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let items = try FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil)
            let audio = items
                .filter { audioExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            if audio.isEmpty {
                message = "App 文件夹里没有音频。可在「文件」App → 我的 iPhone → 本地听书 里拖入文件"
                return
            }
            files = audio
            folderName = "App 文件夹（\(files.count) 个）"
            message = ""
        } catch {
            message = "读取 App 文件夹失败：\(error.localizedDescription)"
        }
    }

    private func restore() {
        if let data = UserDefaults.standard.data(forKey: "folderBookmark") {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) {
                loadFolder(url)
                return
            }
        }
        if let arr = UserDefaults.standard.array(forKey: "fileBookmarks") as? [Data], !arr.isEmpty {
            var urls: [URL] = []
            for data in arr {
                var stale = false
                if let u = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) {
                    _ = u.startAccessingSecurityScopedResource()
                    urls.append(u)
                }
            }
            if !urls.isEmpty {
                files = urls
                folderName = "上次选择的文件（\(files.count) 个）"
            }
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
