import SwiftUI
import UIKit

private enum PlayerSheet: Identifiable {
    case tools
    case episodes

    var id: Int {
        switch self {
        case .tools: return 0
        case .episodes: return 1
        }
    }
}

struct NowPlayingView: View {
    @Binding var tab: MainTab
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
    @State private var sheet: PlayerSheet?
    @State private var showContent = false

    private var collection: Collection? {
        library.collection(forKey: player.currentCollectionKey)
    }

    private var coverImage: UIImage? {
        guard let c = collection, let path = library.coverURL(for: c)?.path else { return nil }
        return UIImage(contentsOfFile: path)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            mainContent

            progressBlock
                .padding(.horizontal, 26)
                .padding(.top, 8)

            controls
                .padding(.top, 2)

            if showContent {
                Color.clear.frame(height: 10)
            } else {
                HStack(spacing: 10) {
                    contentToggle
                    episodeToggle
                    favoriteToggle
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showContent)
        .sheet(item: $sheet) { s in
            switch s {
            case .tools:
                PlayerToolsSheet()
                    .environmentObject(player)
            case .episodes:
                if let c = collection {
                    EpisodeSheet(collection: c)
                        .environmentObject(player)
                        .environmentObject(library)
                }
            }
        }
    }

    // MARK: - 顶栏

    private var topBar: some View {
        HStack(spacing: 0) {
            Button {
                tab = .home
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.onDark)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.black.opacity(0.35)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                    .contentShape(Circle())
            }

            Spacer(minLength: 0)

            Text("正在播放")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.onDark.opacity(0.9))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 1)

            Spacer(minLength: 0)

            Button {
                sheet = .tools
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Theme.onDark)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.black.opacity(0.35)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                    .contentShape(Circle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: - 主区域（普通 / 文稿）

    @ViewBuilder private var mainContent: some View {
        if showContent {
            VStack(spacing: 0) {
                compactHeader
                transcriptArea
            }
        } else {
            ScrollView {
                VStack(spacing: 14) {
                    coverArt(184)
                    titleBlock
                    episodeChip
                }
                .padding(.horizontal, 26)
                .padding(.top, 6)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(player.title.isEmpty ? "未播放" : player.title)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Theme.onDark)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(collection?.name ?? "—")
                .font(.system(size: 12))
                .foregroundStyle(Theme.onDarkMuted)
        }
    }

    @ViewBuilder private var episodeChip: some View {
        if player.queueTotal > 0 {
            Text("第 \(player.queueIndex + 1) 集 · 共 \(player.queueTotal) 集")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.onDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.3)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        }
    }

    // MARK: - 文稿模式

    private var compactHeader: some View {
        HStack(spacing: 10) {
            coverArt(54)

            VStack(alignment: .leading, spacing: 2) {
                Text(player.title.isEmpty ? "未播放" : player.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.onDark)
                    .lineLimit(1)
                Text(collection?.name ?? "—")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.onDarkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Button {
                showContent = false
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.onDark)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.black.opacity(0.35)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                    .contentShape(Circle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var transcriptArea: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 16)
            Image(systemName: "doc.text")
                .font(.system(size: 28))
                .foregroundStyle(Theme.onDarkMuted.opacity(0.55))
            Text("暂时没有内容")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.onDark)
            Text("文稿会显示在这里")
                .font(.system(size: 12))
                .foregroundStyle(Theme.onDarkMuted)
            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
    }

    // MARK: - 底部两个按钮

    private var contentToggle: some View {
        Button {
            showContent = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.text").font(.system(size: 13, weight: .medium))
                Text("文稿").font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Theme.onDark)
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color.black.opacity(0.3)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var episodeToggle: some View {
        Button {
            sheet = .episodes
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "list.number").font(.system(size: 13, weight: .medium))
                Text("选集").font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Theme.onDark)
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color.black.opacity(0.3)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 组件

    private var currentTrack: Track? {
        guard let c = collection else { return nil }
        return c.tracks.first { $0.name == player.title }
    }

    private var isCurrentFavorited: Bool {
        guard let t = currentTrack else { return false }
        return library.isFavoriteTrack(t)
    }

    private var favoriteToggle: some View {
        Button {
            if let t = currentTrack {
                library.toggleFavoriteTrack(t)
            }
        } label: {
            Image(systemName: isCurrentFavorited ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isCurrentFavorited ? Theme.accent : Theme.onDark)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.black.opacity(0.3)))
                .overlay(
                    Capsule().strokeBorder(
                        isCurrentFavorited ? Theme.accent.opacity(0.6) : Color.white.opacity(0.28),
                        lineWidth: 1
                    )
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func coverArt(_ size: CGFloat) -> some View {
        Group {
            if let ui = coverImage {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.coverGradient(for: player.currentCollectionKey)
                    Text(firstChar)
                        .font(.system(size: size * 0.32, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: size * 0.09, y: 8)
    }

    private var progressBlock: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(get: { player.current }, set: { player.seek(to: $0) }),
                in: 0...max(player.duration, 1)
            )
            .tint(.white)

            HStack {
                Text(fmt(player.current))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.onDarkMuted)
                Spacer()
                Text(fmt(player.duration))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.onDarkMuted)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 44) {
            Button {
                player.prev()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.onDark)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }

            Button {
                player.toggle()
            } label: {
                ZStack {
                    Circle().fill(Theme.accentGradient).frame(width: 66, height: 66)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 25))
                        .foregroundStyle(.white)
                }
                .shadow(color: Theme.accent.opacity(0.5), radius: 14, y: 8)
                .contentShape(Circle())
            }

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.onDark)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
    }

    private var firstChar: String {
        guard let c = collection else { return "♪" }
        return String(c.name.prefix(1))
    }
}

struct PlayerToolsSheet: View {
    @EnvironmentObject var player: PlayerModel
    @Environment(\.dismiss) private var dismiss
    @State private var sleepMode = 0
    @State private var sleepMinutes = 30
    @State private var sleepEpisodes = 3

    var body: some View {
        NavigationStack {
            List {
                Section("倍速") {
                    Picker("倍速", selection: Binding(
                        get: { player.rate },
                        set: { player.setRate($0) }
                    )) {
                        Text("0.75×").tag(Float(0.75))
                        Text("1×").tag(Float(1.0))
                        Text("1.25×").tag(Float(1.25))
                        Text("1.5×").tag(Float(1.5))
                        Text("2×").tag(Float(2.0))
                    }
                    .pickerStyle(.segmented)
                }

                Section("定时关闭") {
                    Picker("模式", selection: $sleepMode) {
                        Text("关闭").tag(0)
                        Text("按时间").tag(1)
                        Text("按集数").tag(2)
                    }
                    .pickerStyle(.segmented)

                    if sleepMode == 1 {
                        Stepper("\(sleepMinutes) 分钟后停止", value: $sleepMinutes, in: 1...180)
                        Button("开始计时") { player.setSleepTime(sleepMinutes) }
                    } else if sleepMode == 2 {
                        Stepper("播完 \(sleepEpisodes) 集后停止", value: $sleepEpisodes, in: 1...50)
                        Button("开始计时") { player.setSleepEpisodes(sleepEpisodes) }
                    }

                    if player.sleepMode != .none {
                        Text(sleepStatus).foregroundStyle(Theme.accent)
                        Button("取消定时", role: .destructive) { player.cancelSleep() }
                    }
                }
            }
            .navigationTitle("播放设置")
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

    private var sleepStatus: String {
        switch player.sleepMode {
        case .none:
            return ""
        case .time:
            return "剩余 \(player.sleepRemaining) 秒"
        case .episodes:
            return "再播 \(player.sleepRemaining) 集"
        }
    }
}
