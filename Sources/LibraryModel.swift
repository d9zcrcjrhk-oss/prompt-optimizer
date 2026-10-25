import Foundation
import Combine

let audioExtensions: Set<String> = ["mp3", "m4a", "wav", "flac", "aac", "aiff", "m4b", "caf", "mp4", "ogg", "opus", "wma", "m4r"]

func episodeNumber(_ name: String) -> Int? {
    var digits = ""
    for ch in name {
        if ch.isNumber {
            digits.append(ch)
        } else if !digits.isEmpty {
            break
        }
    }
    return digits.isEmpty ? nil : Int(digits)
}

func fmt(_ s: Double) -> String {
    let t = max(0, Int(s))
    return String(format: "%d:%02d", t / 60, t % 60)
}

struct Track: Identifiable, Hashable {
    let url: URL
    let name: String
    let collection: String
    var id: String { url.path }
}

struct Collection: Identifiable {
    let name: String
    let tracks: [Track]
    var id: String { name }
}

final class LibraryModel: ObservableObject {
    @Published var collections: [Collection] = []
    @Published var lastTrack: Track?
    @Published var importMessage = ""
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    private func folderBookmarks() -> [Data] {
        (UserDefaults.standard.array(forKey: "importedFolderBookmarks") as? [Data]) ?? []
    }

    private func fileBookmarks() -> [Data] {
        (UserDefaults.standard.array(forKey: "importedFileBookmarks") as? [Data]) ?? []
    }

    func scan() {
        var groups: [String: [Track]] = [:]

        // A. App 自己的 Documents 文件夹（复制到手机的）
        if let en = FileManager.default.enumerator(at: docs, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let u as URL in en {
                guard audioExtensions.contains(u.pathExtension.lowercased()) else { continue }
                let rel = u.path.replacingOccurrences(of: docs.path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let parts = rel.components(separatedBy: "/")
                let col = parts.count > 1 ? parts[0] : "未归类"
                groups[col, default: []].append(Track(url: u, name: u.deletingPathExtension().lastPathComponent, collection: col))
            }
        }

        // B. 导入的文件夹（U盘/文件，不复制，直接读）
        for data in folderBookmarks() {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { continue }
            guard url.startAccessingSecurityScopedResource() else { continue }
            let name = url.lastPathComponent.isEmpty ? "外部文件夹" : url.lastPathComponent
            if let en = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for case let u as URL in en {
                    guard audioExtensions.contains(u.pathExtension.lowercased()) else { continue }
                    groups[name, default: []].append(Track(url: u, name: u.deletingPathExtension().lastPathComponent, collection: name))
                }
            }
        }

        // C. 导入的单个文件
        var imported: [Track] = []
        for data in fileBookmarks() {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { continue }
            guard url.startAccessingSecurityScopedResource() else { continue }
            imported.append(Track(url: url, name: url.deletingPathExtension().lastPathComponent, collection: "U盘文件"))
        }
        if !imported.isEmpty {
            groups["U盘文件"] = imported
        }

        collections = groups.keys.sorted().map { key in
            let sorted = (groups[key] ?? []).sorted { a, b in
                let na = episodeNumber(a.name) ?? Int.max
                let nb = episodeNumber(b.name) ?? Int.max
                if na != nb { return na < nb }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
            return Collection(name: key, tracks: sorted)
        }

        if let p = UserDefaults.standard.string(forKey: "lastTrackPath") {
            lastTrack = collections.flatMap { $0.tracks }.first { $0.url.path == p }
        } else {
            lastTrack = nil
        }
    }

    func importFolder(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importMessage = "无法访问（U盘未连接或权限不足）"
            return
        }
        guard let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else {
            importMessage = "无法创建书签"
            return
        }
        var arr = folderBookmarks()
        if !arr.contains(data) { arr.append(data) }
        UserDefaults.standard.set(arr, forKey: "importedFolderBookmarks")
        importMessage = "已添加文件夹：\(url.lastPathComponent)"
        scan()
    }

    func importFiles(_ urls: [URL]) {
        var arr = fileBookmarks()
        var n = 0
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                if !arr.contains(data) {
                    arr.append(data)
                    n += 1
                }
            }
        }
        UserDefaults.standard.set(arr, forKey: "importedFileBookmarks")
        importMessage = "已添加 \(n) 个文件"
        scan()
    }

    func clearImports() {
        UserDefaults.standard.removeObject(forKey: "importedFolderBookmarks")
        UserDefaults.standard.removeObject(forKey: "importedFileBookmarks")
        importMessage = "已清空外部导入"
        scan()
    }

    func queue(for t: Track) -> [Track] {
        collections.first { $0.name == t.collection }?.tracks ?? [t]
    }
}
