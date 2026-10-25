import SwiftUI
import UIKit

struct NowPlayingView: View {
    @Binding var tab: MainTab
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
    @State private var showTools = false
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

            if showContent {
                contentMode
            } else {
                normalMode
            }
        }
        .animation(.easeInOut(duration: 0.28), value: showContent)
        .sheet(isPresented: $showTools) {
            PlayerToolsSheet()
                .environmentObject(player)
                .environmentObject(library)
        }
    }

    // MARK: - 顶栏

    private var topBar: some View {
        HStack {
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

            Spacer()

            Text("正在播放")
                .font(Theme.serif(14, .semibold))
                .foregroundStyle(Theme.onDark.opacity(0.9))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 1)

            Spacer()

            Button {
                showTools = true
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
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - 普通模式

    private var normalMode: some View {
        ScrollView {
            VStack(spacing: 14) {
                coverArt(184)
                titleBlock
                episodeChip
                progressBlock
                controls
                contentToggle
            }
            .padding(.horizontal, 26)
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(player.title.isEmpty ? "未播放" : player.title)
                .font(Theme.serif(19, .semibold))
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

    private var contentToggle: some View {
        Button {
            showContent = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "doc.text").font(.system(size: 14, weight: .medium))
                Text("文稿").font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Theme.onDark)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color.black.opacity(0.3)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 文稿模式（封面缩小，文稿居中）

    private var contentMode: some View {
        VStack(spacing: 0) {
            compactHeader

            transcriptArea

            progressBlock
                .padding(.horizontal, 26)

            controls
                .padding(.bottom, 8)
        }
    }

    private var compactHeader: some View {
        HStack(spacing: 10) {
            coverArt(52)

            VStack(alignment: .leading, spacing: 2) {
                Text(player.title.isEmpty ? "未播放" : player.title)
                    .font(Theme.serif(15, .semibold))
                    .foregroundStyle(Theme.onDark)
                    .lineLimit(1)
                Text(collection?.name ?? "—")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.onDarkMuted)
                    .lineLimit(1)
            }

            Spacer()

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
        .padding(.top, 8)
    }

    private var transcriptArea: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 30))
                .foregroundStyle(Theme.onDarkMuted.opacity(0.55))
            Text("暂时没有内容")
                .font(Theme.serif(16, .medium))
                .foregroundStyle(Theme.onDark)
            Text("文稿会显示在这里")
                .font(.system(size: 12))
                .foregroundStyle(Theme.onDarkMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
    }

    // MARK: - 共用组件

    private func coverArt(_ size: CGFloat) -> some View {
        Group {
            if let ui = coverImage {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.coverGradient(for: player.currentCollectionKey)
                    Text(firstChar)
                        .font(Theme.serif(size * 0.32, .bold))
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
                    Circle().fill(Theme.accentGradient).frame(width: 68, height: 68)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26))
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
        .padding(.vertical, 4)
    }

    private var firstChar: String {
        guard let c = collection else { return "♪" }
        return String(c.name.prefix(1))
    }
}

struct PlayerToolsSheet: View {
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
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

                if let c = currentCollection {
                    Section("选集（\(c.tracks.count) 集）") {
                        ForEach(c.tracks) { t in
                            Button {
                                player.play(t, queue: c.tracks)
                                dismiss()
                            } label: {
                                HStack {
                                    Text("\(episodeNumber(t.name) ?? 0)")
                                        .frame(width: 30, alignment: .trailing)
                                        .foregroundStyle(Theme.muted)
                                    Text(t.name)
                                        .lineLimit(1)
                                        .foregroundStyle(player.title == t.name ? Theme.accent : Theme.text)
                                    Spacer()
                                    if player.title == t.name {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .foregroundStyle(Theme.accent)
                                    }
                                }
                            }
                        }
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
    }

    private var currentCollection: Collection? {
        library.collection(forKey: player.currentCollectionKey)
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
