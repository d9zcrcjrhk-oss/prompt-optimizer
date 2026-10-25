import Foundation
import Combine

let audioExtensions: Set<String> = [
    "mp3", "m4a", "m4b", "m4p", "m4r", "mp2",
    "wav", "wave", "aif", "aifc", "aiff", "caf",
    "flac", "alac", "ape", "aac", "ogg", "oga", "opus",
    "wma", "amr", "3gp", "dsf", "dff", "wv", "webm", "mp4"
]

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
    let collectionKey: String
    var id: String { url.path }
}

struct Collection: Identifiable {
    let id: String
    let folderURL: URL?
    let name: String
    let tracks: [Track]
}

enum WebPlacement {
    case newCollection(String)
    case existing(String)
    case loose
}

final class LibraryModel: ObservableObject {
    static let shared = LibraryModel()

    @Published var collections: [Collection] = []
    @Published var lastTrack: Track?
    @Published var coverRevision = 0
    @Published var importStatus = ""
    @Published var favoriteCollections: [String] = []
    @Published var favoriteTracks: [String] = []

    private var nameOverrides: [String: String] = [:]

    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    init() {
        nameOverrides = (UserDefaults.standard.dictionary(forKey: "nameOverrides") as? [String: String]) ?? [:]
        favoriteCollections = (UserDefaults.standard.array(forKey: "favCollections") as? [String]) ?? []
        favoriteTracks = (UserDefaults.standard.array(forKey: "favTracks") as? [String]) ?? []
    }

    private func folderBookmarks() -> [Data] {
        (UserDefaults.standard.array(forKey: "importedFolderBookmarks") as? [Data]) ?? []
    }

    private func fileBookmarks() -> [Data] {
        (UserDefaults.standard.array(forKey: "importedFileBookmarks") as? [Data]) ?? []
    }

    private var coversDir: URL {
        docs.appendingPathComponent("Covers", isDirectory: true)
    }

    private func stableKey(_ s: String) -> String {
        var hash: UInt64 = 14695981039346656037
        for b in s.utf8 {
            hash ^= UInt64(b)
            hash = hash &* 1099511628211
        }
        return String(hash, radix: 16)
    }

    func scan() {
        var groups: [String: [Track]] = [:]
        var folders: [String: URL] = [:]
        var defaultNames: [String: String] = [:]

        // A. App 自己的 Documents 文件夹
        if let en = FileManager.default.enumerator(at: docs, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let u as URL in en {
                guard audioExtensions.contains(u.pathExtension.lowercased()) else { continue }
                let rel = u.path.replacingOccurrences(of: docs.path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let parts = rel.components(separatedBy: "/")
                let key: String
                let dname: String
                if parts.count > 1 {
                    key = parts[0]
                    dname = parts[0]
                    folders[key] = docs.appendingPathComponent(parts[0])
                } else {
                    key = "__uncat__"
                    dname = "未归类"
                }
                groups[key, default: []].append(Track(url: u, name: u.deletingPathExtension().lastPathComponent, collectionKey: key))
                defaultNames[key] = dname
            }
        }

        // B. 导入的文件夹（security-scoped，不复制）
        for data in folderBookmarks() {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { continue }
            guard url.startAccessingSecurityScopedResource() else { continue }
            let key = "ext:" + url.path
            folders[key] = url
            defaultNames[key] = url.lastPathComponent.isEmpty ? "外部文件夹" : url.lastPathComponent
            if let en = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for case let u as URL in en {
                    guard audioExtensions.contains(u.pathExtension.lowercased()) else { continue }
                    groups[key, default: []].append(Track(url: u, name: u.deletingPathExtension().lastPathComponent, collectionKey: key))
                }
            }
        }

        // C. 导入的单个音频文件（U 盘/文件，security-scoped，不复制）
        for data in fileBookmarks() {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { continue }
            guard url.startAccessingSecurityScopedResource() else { continue }
            let parent = url.deletingLastPathComponent().lastPathComponent
            let pname = parent.isEmpty ? "外部文件" : parent
            let key = "file:" + pname
            defaultNames[key] = pname
            groups[key, default: []].append(Track(url: url, name: url.deletingPathExtension().lastPathComponent, collectionKey: key))
        }

        collections = groups.keys.sorted().map { key in
            let sorted = (groups[key] ?? []).sorted { a, b in
                let na = episodeNumber(a.name) ?? Int.max
                let nb = episodeNumber(b.name) ?? Int.max
                if na != nb { return na < nb }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
            let display = nameOverrides[key] ?? defaultNames[key] ?? key
            return Collection(id: key, folderURL: folders[key], name: display, tracks: sorted)
        }
        updateLastTrack()
    }

    func updateLastTrack() {
        guard let p = UserDefaults.standard.string(forKey: "lastTrackPath") else {
            lastTrack = nil
            return
        }
        lastTrack = collections.flatMap { $0.tracks }.first {
            $0.url.path == p || $0.url.absoluteString == p
        }
    }

    func queue(for t: Track) -> [Track] {
        collections.first { $0.id == t.collectionKey }?.tracks ?? [t]
    }

    func collection(forKey key: String) -> Collection? {
        collections.first { $0.id == key }
    }

    func coverURL(for c: Collection) -> URL? {
        let f = coversDir.appendingPathComponent(stableKey(c.id) + ".jpg")
        if FileManager.default.fileExists(atPath: f.path) { return f }
        if let folder = c.folderURL {
            let u = folder.appendingPathComponent("cover.jpg")
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        return nil
    }

    func saveCover(_ data: Data, for c: Collection) {
        try? FileManager.default.createDirectory(at: coversDir, withIntermediateDirectories: true)
        let f = coversDir.appendingPathComponent(stableKey(c.id) + ".jpg")
        try? data.write(to: f)
        coverRevision += 1
    }

    @discardableResult
    func renameCollection(_ c: Collection, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        nameOverrides[c.id] = trimmed
        UserDefaults.standard.set(nameOverrides, forKey: "nameOverrides")
        scan()
        return true
    }

    func importFolder(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importStatus = "无法访问该文件夹"
            return
        }
        guard let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else {
            importStatus = "无法创建书签"
            return
        }
        var arr = folderBookmarks()
        if !arr.contains(data) { arr.append(data) }
        UserDefaults.standard.set(arr, forKey: "importedFolderBookmarks")
        importStatus = "已导入文件夹：\(url.lastPathComponent)"
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
        importStatus = "已导入 \(n) 个音频（直接读，不复制）"
        scan()
    }

    func clearImports() {
        UserDefaults.standard.removeObject(forKey: "importedFolderBookmarks")
        UserDefaults.standard.removeObject(forKey: "importedFileBookmarks")
        importStatus = "已清空外部导入"
        scan()
    }

    /// 接收从「文件」App 共享/打开到本 App 的音频
    func receiveFile(_ url: URL) {
        let importDir = docs.appendingPathComponent("共享导入", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: importDir, withIntermediateDirectories: true)
        } catch {
            importStatus = "创建目录失败：\(error.localizedDescription)"
            return
        }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        var dest = importDir.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) {
            dest = importDir.appendingPathComponent(UUID().uuidString + "_" + url.lastPathComponent)
        }
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            importStatus = "已接收：\(url.lastPathComponent)"
        } catch {
            importStatus = "接收失败：\(error.localizedDescription)"
        }
        scan()
    }

    // MARK: - 喜欢

    func isFavoriteCollection(_ c: Collection) -> Bool {
        favoriteCollections.contains(c.id)
    }

    func toggleFavoriteCollection(_ c: Collection) {
        if let i = favoriteCollections.firstIndex(of: c.id) {
            favoriteCollections.remove(at: i)
        } else {
            favoriteCollections.insert(c.id, at: 0)
        }
        UserDefaults.standard.set(favoriteCollections, forKey: "favCollections")
    }

    var favoriteCollectionObjects: [Collection] {
        favoriteCollections.compactMap { id in collections.first { $0.id == id } }
    }

    func isFavoriteTrack(_ t: Track) -> Bool {
        favoriteTracks.contains(t.id)
    }

    func toggleFavoriteTrack(_ t: Track) {
        if let i = favoriteTracks.firstIndex(of: t.id) {
            favoriteTracks.remove(at: i)
        } else {
            favoriteTracks.insert(t.id, at: 0)
        }
        UserDefaults.standard.set(favoriteTracks, forKey: "favTracks")
    }

    // MARK: - 删除

    func deleteTrack(_ t: Track) {
        do {
            try FileManager.default.removeItem(at: t.url)
        } catch {
            importStatus = "删除失败：\(error.localizedDescription)"
        }
        removeBookmark(for: t.url)
        favoriteTracks.removeAll { $0 == t.id }
        UserDefaults.standard.set(favoriteTracks, forKey: "favTracks")
        scan()
    }

    func deleteCollection(_ c: Collection) {
        let fm = FileManager.default
        if let folder = c.folderURL {
            try? fm.removeItem(at: folder)
            removeBookmark(for: folder)
        }
        for t in c.tracks {
            removeBookmark(for: t.url)
        }
        let cover = coversDir.appendingPathComponent(stableKey(c.id) + ".jpg")
        try? fm.removeItem(at: cover)
        nameOverrides.removeValue(forKey: c.id)
        UserDefaults.standard.set(nameOverrides, forKey: "nameOverrides")
        favoriteCollections.removeAll { $0 == c.id }
        UserDefaults.standard.set(favoriteCollections, forKey: "favCollections")
        favoriteTracks.removeAll { id in c.tracks.contains { $0.id == id } }
        UserDefaults.standard.set(favoriteTracks, forKey: "favTracks")
        scan()
    }

    private func removeBookmark(for url: URL) {
        var folderArr = folderBookmarks()
        folderArr = folderArr.filter { data in
            var stale = false
            guard let u = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return true }
            return u.path != url.path
        }
        UserDefaults.standard.set(folderArr, forKey: "importedFolderBookmarks")

        var fileArr = fileBookmarks()
        fileArr = fileArr.filter { data in
            var stale = false
            guard let u = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return true }
            return u.path != url.path
        }
        UserDefaults.standard.set(fileArr, forKey: "importedFileBookmarks")
    }

    // MARK: - 网页导入

    @discardableResult
    func importWebFiles(_ files: [ReceivedFile], placement: WebPlacement) -> String {
        let fm = FileManager.default
        var destDir: URL = docs
        var placeDesc = ""

        switch placement {
        case .newCollection(let name):
            let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let folderName = clean.isEmpty ? "导入合集 \(Int(Date().timeIntervalSince1970))" : clean
            destDir = docs.appendingPathComponent(folderName, isDirectory: true)
            do {
                try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            } catch {
                return "创建文件夹失败：\(error.localizedDescription)"
            }
            placeDesc = folderName
        case .existing(let id):
            if let c = collections.first(where: { $0.id == id }), let folder = c.folderURL {
                destDir = folder
                placeDesc = c.name
            } else {
                destDir = docs
                placeDesc = "未归类"
            }
        case .loose:
            destDir = docs
            placeDesc = "未归类"
        }

        var ok = 0
        var firstError = ""

        for f in files {
            guard fm.fileExists(atPath: f.url.path) else {
                if firstError.isEmpty { firstError = "临时文件不存在" }
                continue
            }
            let destName = f.name.isEmpty ? "audio-\(ok).mp3" : f.name
            var dest = destDir.appendingPathComponent(destName)
            if fm.fileExists(atPath: dest.path) {
                dest = destDir.appendingPathComponent(UUID().uuidString.prefix(6) + "_" + destName)
            }
            do {
                try fm.copyItem(at: f.url, to: dest)
                try? fm.removeItem(at: f.url)
                ok += 1
            } catch {
                if firstError.isEmpty { firstError = error.localizedDescription }
            }
        }

        scan()

        let dirCount = (try? fm.contentsOfDirectory(atPath: destDir.path))?.count ?? -1
        let names = collections.prefix(6).map { $0.name }.joined(separator: "、")
        var msg = "收到 \(files.count) 个，导入 \(ok) 个 → \(placeDesc)"
        msg += "\n目录内 \(dirCount) 个文件"
        msg += "\n合集 \(collections.count) 部：\(names)"
        if !firstError.isEmpty {
            msg += "\n错误：\(firstError)"
        }
        importStatus = msg
        return msg
    }
}
