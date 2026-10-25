import SwiftUI
import UIKit

struct NowPlayingView: View {
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
        ZStack {
            Theme.ink.ignoresSafeArea()

            if let ui = coverImage {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 50)
                    .opacity(0.28)
                    .ignoresSafeArea()
            }

            LinearGradient(
                colors: [Theme.ink.opacity(0.55), Theme.ink.opacity(0.9), Theme.ink],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                contentArea
                progressArea
                controls
            }
        }
        .sheet(isPresented: $showTools) {
            PlayerToolsSheet()
                .environmentObject(player)
                .environmentObject(library)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            coverThumb

            VStack(alignment: .leading, spacing: 2) {
                Text("正在聆听")
                    .font(Theme.serif(10))
                    .foregroundStyle(Theme.gold)
                Text(player.title.isEmpty ? "未播放" : player.title)
                    .font(Theme.serif(17, .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(collection?.name ?? "—")
                    .font(Theme.serif(11))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                showTools = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    @ViewBuilder private var coverThumb: some View {
        Group {
            if let ui = coverImage {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.coverFallback
                    Text(firstChar)
                        .font(Theme.serif(18, .bold))
                        .foregroundStyle(Theme.goldSoft)
                }
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.gold.opacity(0.3), lineWidth: 1))
    }

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("内容")
                .font(Theme.serif(11))
                .foregroundStyle(Theme.muted)

            Spacer()

            VStack(spacing: 8) {
                Text("此处静候")
                    .font(Theme.serif(16, .medium))
                    .foregroundStyle(Theme.text.opacity(0.9))
                Text("故事的文字，会在这里慢慢浮现")
                    .font(Theme.serif(12))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface.opacity(0.55)))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.gold.opacity(0.14), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.top, 18)
    }

    private var progressArea: some View {
        VStack(spacing: 5) {
            Slider(
                value: Binding(get: { player.current }, set: { player.seek(to: $0) }),
                in: 0...max(player.duration, 1)
            )
            .tint(Theme.gold)

            HStack {
                Text(fmt(player.current))
                    .font(Theme.serif(11))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text(fmt(player.duration))
                    .font(Theme.serif(11))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 14)
    }

    private var controls: some View {
        HStack(spacing: 48) {
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
                    Circle().fill(Theme.gold).frame(width: 74, height: 74)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.ink)
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
        .padding(.vertical, 20)
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
                        Text(sleepStatus).foregroundStyle(Theme.gold)
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
                                        .foregroundStyle(player.title == t.name ? Theme.gold : Theme.text)
                                    Spacer()
                                    if player.title == t.name {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .foregroundStyle(Theme.gold)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("播放设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.gold)
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
