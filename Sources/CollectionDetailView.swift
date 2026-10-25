import SwiftUI
import UIKit

private enum DeleteTarget {
    case collection
    case track(Track)
}

struct CollectionDetailView: View {
    let collection: Collection
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel

    @State private var deleteTarget: DeleteTarget?
    @State private var confirmDelete = false

    private var deleteMessage: String {
        guard let target = deleteTarget else { return "" }
        switch target {
        case .collection:
            return "将删除整个合集的音频与封面，且不可恢复。"
        case .track:
            return "将删除该音频文件，且不可恢复。"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                trackList
                pendingSection
            }
            .padding(.bottom, 34)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog("确定删除？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let target = deleteTarget {
                    switch target {
                    case .collection:
                        library.deleteCollection(collection)
                    case .track(let t):
                        library.deleteTrack(t)
                    }
                }
                deleteTarget = nil
            }
            Button("取消", role: .cancel) {
                deleteTarget = nil
            }
        } message: {
            Text(deleteMessage)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            coverView
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 20, y: 12)

            Text(collection.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Text("\(collection.tracks.count + pending.count) 集")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))

                Button {
                    library.toggleFavoriteCollection(collection)
                } label: {
                    Image(systemName: library.isFavoriteCollection(collection) ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(library.isFavoriteCollection(collection) ? Theme.accent : Color.white.opacity(0.65))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                library.toggleFavoriteCollection(collection)
            } label: {
                Label(
                    library.isFavoriteCollection(collection) ? "取消喜欢" : "添加喜欢",
                    systemImage: library.isFavoriteCollection(collection) ? "heart.slash" : "heart"
                )
            }
            Button(role: .destructive) {
                deleteTarget = .collection
                confirmDelete = true
            } label: {
                Label("删除合集", systemImage: "trash")
            }
        }
    }

    private var trackList: some View {
        LazyVStack(spacing: 2) {
            ForEach(collection.tracks) { t in
                Button {
                    player.play(t, queue: collection.tracks)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(episodeNumber(t.name) ?? 0)")
                            .font(.system(size: 12))
                            .foregroundStyle(player.title == t.name ? Theme.accent : Color.white.opacity(0.5))
                            .frame(width: 34, alignment: .trailing)

                        Text(t.name)
                            .font(.system(size: 15))
                            .foregroundStyle(player.title == t.name ? Theme.accent : Color.white)
                            .lineLimit(1)

                        Spacer()

                        if library.isFavoriteTrack(t) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.accent)
                        }

                        if player.title == t.name {
                            Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(player.title == t.name ? Theme.accent.opacity(0.14) : Color.clear)
                    )
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        library.toggleFavoriteTrack(t)
                    } label: {
                        Label(
                            library.isFavoriteTrack(t) ? "取消喜欢" : "添加喜欢",
                            systemImage: library.isFavoriteTrack(t) ? "heart.slash" : "heart"
                        )
                    }
                    Button(role: .destructive) {
                        deleteTarget = .track(t)
                        confirmDelete = true
                    } label: {
                        Label("删除这一集", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var pending: [WebEpisode] {
        let names = Set(collection.tracks.map { $0.name })
        return library.loadWebEpisodes(collection.id).filter {
            !names.contains(($0.name as NSString).deletingPathExtension)
        }
    }

    private var pendingSection: some View {
        Group {
            if !pending.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("待下载（\(pending.count)）")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.top, 18)
                        .padding(.bottom, 4)

                    ForEach(pending) { ep in
                        Button {
                            downloadPending(ep)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "icloud.and.arrow.down")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.accent)
                                Text(ep.name)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .lineLimit(1)
                                Spacer(minLength: 6)
                                Text(WebSource.shared.alive ? "待下载" : "需重新导入")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
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

    @ViewBuilder private var coverView: some View {
        if let path = library.coverURL(for: collection)?.path,
           let ui = UIImage(contentsOfFile: path) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            ZStack {
                Theme.coverGradient(for: collection.id)
                Text(String(collection.name.prefix(1)))
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }
}
