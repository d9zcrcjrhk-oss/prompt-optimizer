import SwiftUI
import UIKit
import UniformTypeIdentifiers

let audioExtensions: Set<String> = ["mp3", "m4a", "wav", "flac", "aac", "aiff", "m4b", "caf", "mp4", "ogg", "opus", "wma"]

final class IOSFolderPicker: NSObject, UIDocumentPickerDelegate {
    static let shared = IOSFolderPicker()
    private var completion: ((URL?) -> Void)?

    func present(completion: @escaping (URL?) -> Void) {
        self.completion = completion
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.keyWindow?.rootViewController
        else {
            completion(nil)
            return
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        root.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completion?(urls.first)
        completion = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion?(nil)
        completion = nil
    }
}

struct RootView: View {
    @EnvironmentObject var player: PlayerModel
    @State private var showFilePicker = false
    @State private var files: [URL] = []
    @State private var folderName = ""
    @State private var message = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("推荐导入方式（最稳）")
                        .font(.headline)
                    Text("1. 打开「文件」App\n2. 进入「我的 iPhone」→「本地听书」\n3. 把你的音频文件夹拖/拷进去\n4. 回到本页，点下面的「重新扫描」")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        scanAppDocuments()
                        if !message.isEmpty { } // message shown below
                    } label: {
                        Label("重新扫描 App 文件夹", systemImage: "arrow.clockwise")
                    }
                }

                Section("其它导入方式") {
                    Button {
                        pickFolder()
                    } label: {
                        Label("导入整个文件夹（系统选择器）", systemImage: "folder.badge.plus")
                    }
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("选择音频文件（可多选）", systemImage: "music.note.list")
                    }
                    Text("提示：用系统选择器时，进入目标文件夹后点右上角「打开」；若点了没反应，请用上面的「文件 App」方式。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !folderName.isEmpty {
                    Section("当前") {
                        Text(folderName).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if !message.isEmpty {
                    Section {
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
                }

                Section {
                    Text("版本 v3 · 启动自动扫描 App 文件夹")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("本地听书")
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

    private func pickFolder() {
        IOSFolderPicker.shared.present { url in
            guard let url = url else {
                message = "已取消选择"
                return
            }
            loadFolder(url)
        }
    }

    private func audioFiles(in folder: URL) -> [URL] {
        var result: [URL] = []
        if let en = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for case let u as URL in en {
                if audioExtensions.contains(u.pathExtension.lowercased()) {
                    result.append(u)
                }
            }
        }
        return result.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    private func loadFolder(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            message = "无法访问该文件夹（权限不足）"
            return
        }
        let audio = audioFiles(in: url)
        if audio.isEmpty {
            message = "该文件夹（含子文件夹）里没找到音频文件"
            return
        }
        files = audio
        folderName = "\(url.lastPathComponent)（含子文件夹，共 \(files.count) 个）"
        message = ""
        if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: "folderBookmark")
            UserDefaults.standard.removeObject(forKey: "fileBookmarks")
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
        files = ok.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        folderName = "已选文件（\(files.count) 个）"
        message = ""
        UserDefaults.standard.set(bookmarks, forKey: "fileBookmarks")
        UserDefaults.standard.removeObject(forKey: "folderBookmark")
    }

    private func scanAppDocuments() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audio = audioFiles(in: docs)
        if audio.isEmpty {
            message = "App 文件夹里暂时没有音频。请按上面的「推荐导入方式」把文件放进「本地听书」文件夹。"
            return
        }
        files = audio
        folderName = "App 文件夹（含子文件夹，共 \(files.count) 个）"
        message = ""
    }

    private func restore() {
        // 方案 A：优先还原上次的文件夹书签
        if let data = UserDefaults.standard.data(forKey: "folderBookmark") {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) {
                loadFolder(url)
                return
            }
        }
        // 方案 B：还原上次选中的文件
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
                return
            }
        }
        // 方案 C：兜底 —— 自动扫描 App 自己的文件夹
        scanAppDocuments()
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
