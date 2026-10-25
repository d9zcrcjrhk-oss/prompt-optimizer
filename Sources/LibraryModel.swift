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
    @Published var networkCollections: [Collection] = []
    @Published var lastTrack: Track?
    @Published var importMessage = ""
    @Published var networkStatus = ""
    @Published var networkBase: String = UserDefaults.standard.string(forKey: "networkBase") ?? ""

    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    var allCollections: [Collection] { collections + networkCollections }

    private func folderBookmarks() -> [Data] {
        (UserDefaults.standard.array(forKey: "importedFolderBookmarks") as? [Data]) ?? []
    }

    private func fileBookmarks() -> [Data] {
        (UserDefaults.standard.array(forKey: "importedFileBookmarks") as? [Data]) ?? []
    }

    func scan() {
        var groups: [String: [Track]] = [:]

        if let en = FileManager.default.enumerator(at: docs, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let u as URL in en {
                guard audioExtensions.contains(u.pathExtension.lowercased()) else { continue }
                let rel = u.path.replacingOccurrences(of: docs.path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let parts = rel.components(separatedBy: "/")
                let col = parts.count > 1 ? parts[0] : "未归类"
                groups[col, default: []].append(Track(url: u, name: u.deletingPathExtension().lastPathComponent, collection: col))
            }
        }

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
        updateLastTrack()
    }

    func updateLastTrack() {
        guard let p = UserDefaults.standard.string(forKey: "lastTrackPath") else {
            lastTrack = nil
            return
        }
        lastTrack = allCollections.flatMap { $0.tracks }.first {
            $0.url.path == p || $0.url.absoluteString == p
        }
    }

    func queue(for t: Track) -> [Track] {
        allCollections.first { $0.name == t.collection }?.tracks ?? [t]
    }

    func loadNetwork() async {
        let base = networkBase.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !base.isEmpty else {
            networkStatus = "请先填服务器地址"
            return
        }
        networkStatus = "连接中…"
        guard let listURL = URL(string: base + "/api/list") else {
            networkStatus = "地址无效"
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: listURL)
            struct Resp: Decodable {
                struct Item: Decodable {
                    let path: String
                    let name: String
                    let size: Int
                }
                let items: [Item]
            }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            var groups: [String: [Track]] = [:]
            for it in resp.items {
                let parts = it.path.components(separatedBy: "/")
                let book = parts.count >= 3 ? parts[1] : (parts.first ?? "网络")
                let url = mediaURL(base: base, path: it.path)
                groups[book, default: []].append(Track(url: url, name: it.name, collection: book))
            }
            networkCollections = groups.keys.sorted().map { key in
                let sorted = (groups[key] ?? []).sorted { a, b in
                    let na = episodeNumber(a.name) ?? Int.max
                    let nb = episodeNumber(b.name) ?? Int.max
                    if na != nb { return na < nb }
                    return a.name.localizedStandardCompare(b.name) == .orderedAscending
                }
                return Collection(name: key, tracks: sorted)
            }
            networkStatus = "已加载 \(resp.items.count) 个音频 · \(networkCollections.count) 个合集"
            networkBase = base
            UserDefaults.standard.set(base, forKey: "networkBase")
            updateLastTrack()
        } catch {
            networkStatus = "连接失败：\(error.localizedDescription)"
        }
    }

    private func mediaURL(base: String, path: String) -> URL {
        let encoded = path.components(separatedBy: "/").map { seg in
            seg.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? seg
        }.joined(separator: "/")
        return URL(string: base + "/media/" + encoded) ?? URL(string: base)!
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
}
