import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
    @State private var showPlayer = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let last = library.lastTrack {
                        HeroCard(last: last)
                    }

                    Text("我的合集")
                        .font(.title3).bold()
                        .padding(.horizontal, 20)

                    if library.collections.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "folder.badge.plus")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("还没有音频")
                                .font(.headline)
                            Text("把音频文件夹放进「文件」App → 我的 iPhone → 本地听书，再点下面的重新扫描。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(30)
                    } else {
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(library.collections) { c in
                                NavigationLink {
                                    CollectionDetailView(collection: c, showPlayer: $showPlayer)
                                } label: {
                                    CollectionCard(collection: c)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .id(library.coverRevision)
                    }

                    Button {
                        library.scan()
                    } label: {
                        Label("重新扫描", systemImage: "arrow.clockwise")
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .background(Color(uiColor: .systemGroupedBackground))
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

struct HeroCard: View {
    let last: Track
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel

    var body: some View {
        Button {
            player.play(last, queue: library.queue(for: last))
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 4) {
                    Text("继续上次")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(last.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(last.collection)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.30, green: 0.55, blue: 0.98), Color(red: 0.55, green: 0.35, blue: 0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.2), radius: 10, y: 6)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }
}

struct CollectionCard: View {
    let collection: Collection
    @EnvironmentObject var library: LibraryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            Text(collection.name)
                .font(.subheadline).bold()
                .lineLimit(1)
                .foregroundStyle(.primary)
            Text("\(collection.tracks.count) 集")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var cover: some View {
        if let path = library.coverURL(for: collection)?.path, let ui = UIImage(contentsOfFile: path) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [Color(red: 0.55, green: 0.78, blue: 1.0), Color(red: 0.35, green: 0.52, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Text(String(collection.name.prefix(1)))
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.white)
            )
        }
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
