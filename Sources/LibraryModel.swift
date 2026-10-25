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
    let id: String          // 稳定 key（文件夹名 / __uncat__）
    let folderURL: URL?
    let name: String        // 显示名（可被重命名覆盖）
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

    func scan() {
        var groups: [String: [Track]] = [:]
        var folders: [String: URL] = [:]
        var defaultNames: [String: String] = [:]

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
        let folder = c.folderURL ?? docs
        let u = folder.appendingPathComponent("cover.jpg")
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    func saveCover(_ data: Data, for c: Collection) {
        let folder = c.folderURL ?? docs
        let u = folder.appendingPathComponent("cover.jpg")
        try? data.write(to: u)
        coverRevision += 1
    }

    /// 重命名 = 存显示名映射（文件夹不动，绝不失败）
    @discardableResult
    func renameCollection(_ c: Collection, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        nameOverrides[c.id] = trimmed
        UserDefaults.standard.set(nameOverrides, forKey: "nameOverrides")
        scan()
        return true
    }
}
