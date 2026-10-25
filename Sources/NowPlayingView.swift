import SwiftUI
import UIKit

struct NowPlayingView: View {
    @Binding var tab: MainTab
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
    @State private var showTools = false

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
                    progressBlock
                    controls
                    contentCard
                }
                .padding(.horizontal, 26)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showTools) {
            PlayerToolsSheet()
                .environmentObject(player)
                .environmentObject(library)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                tab = .home
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }

            Spacer()

            Text("正在播放")
                .font(Theme.serif(14, .semibold))
                .foregroundStyle(Theme.text)

            Spacer()

            Button {
                showTools = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Theme.text)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 4)
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
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.2), radius: 18, y: 10)
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(player.title.isEmpty ? "未播放" : player.title)
                .font(Theme.serif(20, .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(collection?.name ?? "—")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
        }
    }

    private var progressBlock: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(get: { player.current }, set: { player.seek(to: $0) }),
                in: 0...max(player.duration, 1)
            )
            .tint(Theme.accent)

            HStack {
                Text(fmt(player.current)).font(.system(size: 11)).foregroundStyle(Theme.muted)
                Spacer()
                Text(fmt(player.duration)).font(.system(size: 11)).foregroundStyle(Theme.muted)
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
                    .foregroundStyle(Theme.text)
            }

            Button {
                player.toggle()
            } label: {
                ZStack {
                    Circle().fill(Theme.accent).frame(width: 68, height: 68)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                }
            }

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.text)
            }
        }
        .padding(.vertical, 4)
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("内容")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)

            Text("此处暂时没有内容")
                .font(Theme.serif(14))
                .foregroundStyle(Theme.text.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 18)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
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
