import SwiftUI
import UIKit

enum MainTab {
    case home
    case playing
}

struct MainView: View {
    @State private var tab: MainTab = .home
    @State private var showSettings = false
    @EnvironmentObject var player: PlayerModel

    var body: some View {
        ZStack(alignment: .bottom) {
            if tab == .playing {
                NowPlayingBackdrop()
            } else {
                Color.black.ignoresSafeArea()
            }

            Group {
                if tab == .home {
                    HomeView(tab: $tab)
                } else {
                    NowPlayingView(tab: $tab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if tab == .home {
                VStack(spacing: 10) {
                    if player.hasTrack {
                        MiniPlayerBar {
                            tab = .playing
                        }
                    }
                    FloatingTabBar(tab: $tab) {
                        showSettings = true
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
        .tint(Theme.accent)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

/// 播放页的全屏背景：封面模糊 + 暗色蒙层（严格约束为屏幕尺寸）
struct NowPlayingBackdrop: View {
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel

    private var coverImage: UIImage? {
        guard let c = library.collection(forKey: player.currentCollectionKey),
              let path = library.coverURL(for: c)?.path else { return nil }
        return UIImage(contentsOfFile: path)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let ui = coverImage {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 55)
                        .opacity(0.55)
                        .scaleEffect(1.2)
                } else {
                    Theme.accentGradient
                }

                Color.black.opacity(0.38)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.45),
                        Color.black.opacity(0.15),
                        Color.black.opacity(0.50)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}

/// 悬浮玻璃底栏（Apple Music 风格）
struct FloatingTabBar: View {
    @Binding var tab: MainTab
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            item("books.vertical.fill", "书架", active: tab == .home) {
                tab = .home
            }

            Button {
                tab = .playing
            } label: {
                SpinningCover()
            }
            .frame(maxWidth: .infinity)

            item("gearshape.fill", "设置", active: false) {
                onSettings()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 30)
    }

    private func item(_ icon: String, _ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 18))
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(active ? Theme.accent : Color.white.opacity(0.72))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(active ? Color.white.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

/// 悬浮迷你播放条
struct MiniPlayerBar: View {
    let onOpen: () -> Void
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel

    private var collection: Collection? {
        library.collection(forKey: player.currentCollectionKey)
    }

    private var coverImage: UIImage? {
        guard let c = collection, let path = library.coverURL(for: c)?.path else { return nil }
        return UIImage(contentsOfFile: path)
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onOpen()
            } label: {
                HStack(spacing: 10) {
                    thumb
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(player.title.isEmpty ? "未播放" : player.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(collection?.name ?? "—")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassCard(cornerRadius: 24)
    }

    @ViewBuilder private var thumb: some View {
        if let ui = coverImage {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            ZStack {
                Theme.coverGradient(for: player.currentCollectionKey)
                Image(systemName: "music.note")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
            }
        }
    }
}

func openFilesApp() {
    if let url = URL(string: "shareddocuments://") {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("应用")
                        Spacer()
                        Text("本地听书").foregroundStyle(.secondary)
                    }
                }
                Section {
                    Text("更多设置将在后续版本加入")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct SpinningCover: View {
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
    @State private var spin = false

    var body: some View {
        ZStack {
            coverContent
            Circle().stroke(Color.white.opacity(0.5), lineWidth: 1.5)
            Circle().fill(Theme.accent).frame(width: 5, height: 5)
        }
        .frame(width: 46, height: 46)
        .clipShape(Circle())
        .rotationEffect(.degrees(spin ? 360 : 0))
        .animation(spin ? Animation.linear(duration: 7).repeatForever(autoreverses: false) : .default, value: spin)
        .onAppear { spin = player.isPlaying }
        .onChange(of: player.isPlaying) { playing in spin = playing }
    }

    @ViewBuilder private var coverContent: some View {
        if let c = currentCollection,
           let path = library.coverURL(for: c)?.path,
           let ui = UIImage(contentsOfFile: path) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else if let c = currentCollection {
            ZStack {
                Theme.coverGradient(for: c.id)
                Text(String(c.name.prefix(1)))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
        } else {
            ZStack {
                Color.white.opacity(0.12)
                Image(systemName: "music.note").foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var currentCollection: Collection? {
        guard !player.currentCollectionKey.isEmpty else { return nil }
        return library.collections.first { $0.id == player.currentCollectionKey }
    }
}
