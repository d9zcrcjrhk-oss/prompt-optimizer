import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
    @State private var showPlayer = false
    @State private var showFolderImport = false
    @State private var showFileImport = false

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

                Section("从 U盘 / 文件导入（不复制，直接读）") {
                    Button {
                        showFolderImport = true
                    } label: {
                        Label("选择文件夹（U盘/文件）", systemImage: "folder.badge.plus")
                    }
                    Button {
                        showFileImport = true
                    } label: {
                        Label("选择音频文件（U盘/文件）", systemImage: "music.note.list")
                    }
                    Text("选中后直接读原文件、不复制到手机；播放时 U盘需保持连接。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("合集（\(library.collections.count)）") {
                    if library.collections.isEmpty {
                        Text("还没有合集。用上面「选择文件夹」从 U 盘导入。")
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

                Section("手机内 App 文件夹") {
                    Button {
                        library.scan()
                    } label: {
                        Label("重新扫描", systemImage: "arrow.clockwise")
                    }
                    Text("也可把音频放进：文件 App → 我的 iPhone → 本地听书")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !library.importMessage.isEmpty {
                    Section {
                        Text(library.importMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        library.clearImports()
                    } label: {
                        Label("清空 U盘/外部导入", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("本地听书")
            .fileImporter(
                isPresented: $showFolderImport,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for u in urls { library.importFolder(u) }
                case .failure(let err):
                    library.importMessage = "选择文件夹失败：\(err.localizedDescription)"
                }
            }
            .fileImporter(
                isPresented: $showFileImport,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    library.importFiles(urls)
                case .failure(let err):
                    library.importMessage = "选择文件失败：\(err.localizedDescription)"
                }
            }
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
