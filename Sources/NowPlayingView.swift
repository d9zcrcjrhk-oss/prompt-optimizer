import SwiftUI
import UIKit

struct NowPlayingView: View {
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
    @State private var showTools = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                coverThumb
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.title.isEmpty ? "未播放" : player.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(collectionName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showTools = true
                } label: {
                    Image(systemName: "slider.horizontal.3").font(.title3)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            VStack(spacing: 4) {
                Slider(
                    value: Binding(get: { player.current }, set: { player.seek(to: $0) }),
                    in: 0...max(player.duration, 1)
                )
                HStack {
                    Text(fmt(player.current)).font(.caption2)
                    Spacer()
                    Text(fmt(player.duration)).font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            VStack(spacing: 10) {
                Text("内容")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Text("暂时没有内容")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .padding(.horizontal, 20)
            .padding(.top, 16)

            HStack(spacing: 56) {
                Button {
                    player.prev()
                } label: {
                    Image(systemName: "backward.end.fill").font(.system(size: 30))
                }
                Button {
                    player.toggle()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 66))
                }
                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.end.fill").font(.system(size: 30))
                }
            }
            .padding(.vertical, 18)
        }
        .sheet(isPresented: $showTools) {
            PlayerToolsSheet()
                .environmentObject(player)
                .environmentObject(library)
        }
    }

    @ViewBuilder private var coverThumb: some View {
        Group {
            if let c = collection, let path = library.coverURL(for: c)?.path, let ui = UIImage(contentsOfFile: path) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(red: 0.55, green: 0.78, blue: 1.0), Color(red: 0.35, green: 0.52, blue: 0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Text(firstChar)
                        .font(.title3).bold()
                        .foregroundStyle(.white)
                )
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var collection: Collection? {
        library.collection(forKey: player.currentCollectionKey)
    }

    private var collectionName: String {
        collection?.name ?? "—"
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
                        Text(sleepStatus).foregroundStyle(.orange)
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
                                        .frame(width: 30)
                                        .foregroundStyle(.secondary)
                                    Text(t.name).lineLimit(1)
                                    Spacer()
                                    if player.title == t.name {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .foregroundStyle(Color.accentColor)
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
