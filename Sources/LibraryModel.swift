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
    let folderURL: URL?
    let tracks: [Track]
    var id: String { name }
}

final class LibraryModel: ObservableObject {
    @Published var collections: [Collection] = []
    @Published var lastTrack: Track?
    @Published var coverRevision = 0

    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    func scan() {
        var groups: [String: [Track]] = [:]
        var folders: [String: URL] = [:]

        if let en = FileManager.default.enumerator(at: docs, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let u as URL in en {
                guard audioExtensions.contains(u.pathExtension.lowercased()) else { continue }
                let rel = u.path.replacingOccurrences(of: docs.path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let parts = rel.components(separatedBy: "/")
                if parts.count > 1 {
                    let col = parts[0]
                    folders[col] = docs.appendingPathComponent(col)
                    groups[col, default: []].append(Track(url: u, name: u.deletingPathExtension().lastPathComponent, collection: col))
                } else {
                    groups["未归类", default: []].append(Track(url: u, name: u.deletingPathExtension().lastPathComponent, collection: "未归类"))
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
            return Collection(name: key, folderURL: folders[key], tracks: sorted)
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
        collections.first { $0.name == t.collection }?.tracks ?? [t]
    }

    /// 合集封面文件：<合集文件夹>/cover.jpg
    func coverURL(for c: Collection) -> URL? {
        let folder = c.folderURL ?? docs
        let u = folder.appendingPathComponent("cover.jpg")
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    func saveCover(_ data: Data, for c: Collection) {
        let folder = c.folderURL ?? docs
        let u = folder.appendingPathComponent("cover.jpg")
        do {
            try data.write(to: u)
            coverRevision += 1
        } catch {
            coverRevision += 1
        }
    }

    /// 重命名合集 = 重命名它的物理文件夹（封面会跟着走）
    @discardableResult
    func renameCollection(_ c: Collection, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != c.name, let old = c.folderURL else { return false }
        let new = old.deletingLastPathComponent().appendingPathComponent(trimmed)
        guard !FileManager.default.fileExists(atPath: new.path) else { return false }
        do {
            try FileManager.default.moveItem(at: old, to: new)
            scan()
            return true
        } catch {
            return false
        }
    }
}
