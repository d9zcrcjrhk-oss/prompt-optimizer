import SwiftUI
import UIKit

private enum PlayerSheet: Identifiable {
    case tools
    case content

    var id: Int {
        switch self {
        case .tools: return 0
        case .content: return 1
        }
    }
}

struct NowPlayingView: View {
    @Binding var tab: MainTab
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
    @State private var sheet: PlayerSheet?

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

            ScrollView {
                VStack(spacing: 16) {
                    coverArt
                    titleBlock
                    episodeChip
                    progressBlock
                    controls
                    contentButton
                }
                .padding(.horizontal, 26)
                .padding(.top, 6)
                .padding(.bottom, 20)
            }
        }
        .sheet(item: $sheet) { s in
            switch s {
            case .tools:
                PlayerToolsSheet()
                    .environmentObject(player)
                    .environmentObject(library)
            case .content:
                ContentSheet(title: player.title)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                tab = .home
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.onDark)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                    .contentShape(Circle())
            }

            Spacer()

            Text("正在播放")
                .font(Theme.serif(14, .semibold))
                .foregroundStyle(Theme.onDark.opacity(0.9))

            Spacer()

            Button {
                sheet = .tools
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Theme.onDark)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                    .contentShape(Circle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private var coverArt: some View {
        Group {
            if let ui = coverImage {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.coverGradient(for: player.currentCollectionKey)
                    Text(firstChar)
                        .font(Theme.serif(64, .bold))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
        .frame(width: 210, height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 22, y: 12)
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(player.title.isEmpty ? "未播放" : player.title)
                .font(Theme.serif(20, .semibold))
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
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
        }
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
                    Circle().fill(Theme.accentGradient).frame(width: 70, height: 70)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 27))
                        .foregroundStyle(.white)
                }
                .shadow(color: Theme.accent.opacity(0.5), radius: 16, y: 8)
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

    private var contentButton: some View {
        Button {
            sheet = .content
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14, weight: .medium))
                Text("文稿")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Theme.onDark)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var firstChar: String {
        guard let c = collection else { return "♪" }
        return String(c.name.prefix(1))
    }
}

struct ContentSheet: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 20)

                if !title.isEmpty {
                    Text(title)
                        .font(Theme.serif(16, .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }

                Text("暂时没有内容")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .navigationTitle("文稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .presentationDetents([.medium])
        }
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
