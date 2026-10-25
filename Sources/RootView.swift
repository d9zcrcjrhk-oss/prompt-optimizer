import SwiftUI

struct RootView: View {
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
    @State private var showPlayer = false

    var body: some View {
        NavigationStack {
            List {
                if let last = library.lastTrack {
                    Section {
                        Button {
                            player.play(last, queue: library.queue(for: last))
                            showPlayer = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "play.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading) {
                                    Text("继续上次").font(.headline)
                                    Text(last.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                        }
                    }
                }

                Section("合集（\(library.collections.count)）") {
                    if library.collections.isEmpty {
                        Text("还没有音频。把音频文件夹放进「文件」App → 我的 iPhone → 本地听书，再点下面的重新扫描。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(library.collections) { c in
                        NavigationLink {
                            TrackListView(collection: c, showPlayer: $showPlayer)
                        } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.accentColor.opacity(0.15))
                                    .frame(width: 46, height: 46)
                                    .overlay(
                                        Text(String(c.name.prefix(1)))
                                            .font(.headline)
                                            .foregroundColor(.accentColor)
                                    )
                                VStack(alignment: .leading) {
                                    Text(c.name).font(.headline).lineLimit(1)
                                    Text("\(c.tracks.count) 集").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        library.scan()
                    } label: {
                        Label("重新扫描", systemImage: "arrow.clockwise")
                    }
                    Text("把音频放进「文件」App → 我的 iPhone → 本地听书，再点重新扫描。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("本地听书")
            .safeAreaInset(edge: .bottom) {
                if player.hasTrack {
                    MiniBar(showPlayer: $showPlayer)
                }
            }
            .sheet(isPresented: $showPlayer) {
                PlayerView().environmentObject(player)
            }
            .task { library.scan() }
        }
    }
}

struct TrackListView: View {
    let collection: Collection
    @Binding var showPlayer: Bool
    @EnvironmentObject var player: PlayerModel

    var body: some View {
        List {
            ForEach(collection.tracks) { t in
                Button {
                    player.play(t, queue: collection.tracks)
                    showPlayer = true
                } label: {
                    HStack {
                        Text("\(episodeNumber(t.name) ?? 0)")
                            .frame(width: 32)
                            .foregroundStyle(.secondary)
                        Text(t.name).lineLimit(1)
                        Spacer()
                        if player.title == t.name {
                            Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        }
        .navigationTitle(collection.name)
    }
}

struct MiniBar: View {
    @EnvironmentObject var player: PlayerModel
    @Binding var showPlayer: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading) {
                Text(player.title).font(.footnote).lineLimit(1)
                Text(player.isPlaying ? "播放中" : "已暂停").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
            }
            Button {
                player.next()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title3)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .contentShape(Rectangle())
        .onTapGesture { showPlayer = true }
    }
}
