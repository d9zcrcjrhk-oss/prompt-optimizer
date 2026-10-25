import SwiftUI
import UIKit

struct EpisodeSheet: View {
    let collection: Collection
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
    @Environment(\.dismiss) private var dismiss

    private var groupStarts: [Int] {
        let n = collection.tracks.count
        guard n > 0 else { return [] }
        return Array(stride(from: 0, to: n, by: 100))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    header

                    ForEach(groupStarts, id: \.self) { start in
                        sectionHeader(start)
                        ForEach(start..<min(start + 100, collection.tracks.count), id: \.self) { i in
                            row(i, collection.tracks[i])
                        }
                    }

                    if !pending.isEmpty {
                        sectionHeaderText("待下载（\(pending.count)）")
                        ForEach(pending) { ep in
                            pendingRow(ep)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .background(Color.black)
            .navigationTitle("选集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }

    private var header: some View {
        HStack(spacing: 12) {
            cover
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("共 \(collection.tracks.count) 集")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
    }

    private func sectionHeader(_ start: Int) -> some View {
        Text(rangeTitle(start))
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.45))
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }

    private var pending: [WebEpisode] {
        let names = Set(collection.tracks.map { $0.name })
        return library.loadWebEpisodes(collection.id).filter {
            !names.contains(($0.name as NSString).deletingPathExtension)
        }
    }

    private func sectionHeaderText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.45))
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 4)
    }

    private func pendingRow(_ ep: WebEpisode) -> some View {
        Button {
            downloadPending(ep)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 36)
                Text(ep.name)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
                Spacer(minLength: 6)
                Text(WebSource.shared.alive ? "待下载" : "需重新导入")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }

    private func downloadPending(_ ep: WebEpisode) {
        guard WebSource.shared.alive else { return }
        let eps = library.loadWebEpisodes(collection.id)
        guard let idx = eps.firstIndex(where: { $0.name == ep.name }) else { return }
        let dir = library.docs.appendingPathComponent(collection.id, isDirectory: true)
        WebSource.shared.fetch(index: idx, progress: nil) { url in
            if let url = url {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let dest = dir.appendingPathComponent(ep.name)
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.moveItem(at: url, to: dest)
            }
            DispatchQueue.main.async {
                var arr = library.loadWebEpisodes(collection.id)
                if let i = arr.firstIndex(where: { $0.name == ep.name }), url != nil {
                    arr[i].downloaded = true
                }
                library.saveWebEpisodes(collection.id, arr)
                library.scan()
            }
        }
    }

    private func rangeTitle(_ start: Int) -> String {
        let end = min(start + 100, collection.tracks.count)
        return "第 \(start + 1)–\(end) 集"
    }

    private func row(_ i: Int, _ t: Track) -> some View {
        let isCurrent = player.title == t.name
        let isFav = library.isFavoriteTrack(t)

        return Button {
            player.play(t, queue: collection.tracks)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text("\(i + 1)")
                    .font(.system(size: 12))
                    .foregroundStyle(isCurrent ? Theme.accent : Color.white.opacity(0.45))
                    .frame(width: 36, alignment: .trailing)

                Text(t.name)
                    .font(.system(size: 15))
                    .foregroundStyle(isCurrent ? Theme.accent : Color.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 6)

                if isFav {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.accent)
                }

                if isCurrent {
                    Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isCurrent ? Theme.accent.opacity(0.14) : Color.clear)
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var cover: some View {
        if let path = library.coverURL(for: collection)?.path,
           let ui = UIImage(contentsOfFile: path) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            ZStack {
                Theme.coverGradient(for: collection.id)
                Text(String(collection.name.prefix(1)))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }
}
