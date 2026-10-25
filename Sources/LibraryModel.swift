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
    let collectionKey: String
    var id: String { url.path }
}

struct Collection: Identifiable {
    let id: String
    let folderURL: URL?
    let name: String
    let tracks: [Track]
}

final class LibraryModel: ObservableObject {
    @Published var collections: [Collection] = []
    @Published var lastTrack: Track?
    @Published var coverRevision = 0

    private var nameOverrides: [String: String] = [:]

    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    init() {
        nameOverrides = (UserDefaults.standard.dictionary(forKey: "nameOverrides") as? [String: String]) ?? [:]
    }

    private func folderBookmarks() -> [Data] {
        (UserDefaults.standard.array(forKey: "importedFolderBookmarks") as? [Data]) ?? []
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

        // B. 导入的文件夹（U盘 / 文件，security-scoped，不复制）
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
        guard url.startAccessingSecurityScopedResource() else { return }
        guard let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else { return }
        var arr = folderBookmarks()
        if !arr.contains(data) { arr.append(data) }
        UserDefaults.standard.set(arr, forKey: "importedFolderBookmarks")
        scan()
    }

    func clearImports() {
        UserDefaults.standard.removeObject(forKey: "importedFolderBookmarks")
        scan()
    }
}
