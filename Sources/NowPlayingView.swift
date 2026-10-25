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

            if !library.finishDebug.isEmpty {
                Text(library.finishDebug)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.onDarkMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }

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
                    .environmentObject(library)
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
    @EnvironmentObject var library: LibraryModel
    @Environment(\.dismiss) private var dismiss

    private var collection: Collection? {
        library.collection(forKey: player.currentCollectionKey)
    }

    private var coverImage: UIImage? {
        guard let c = collection, let path = library.coverURL(for: c)?.path else { return nil }
        return UIImage(contentsOfFile: path)
    }

    private var firstChar: String {
        guard let c = collection else { return "♪" }
        return String(c.name.prefix(1))
    }

    private let rateOptions: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
    private let minuteOptions: [Int] = [15, 30, 45, 60]
    private let episodeOptions: [Int] = [1, 2, 3, 5]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    trackCard
                    speedSection
                    sleepSection
                    hintCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .background(Color.black)
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

    private var trackCard: some View {
        HStack(spacing: 12) {
            coverThumb
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(player.title.isEmpty ? "未播放" : player.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(collection?.name ?? "—")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
    }

    private var speedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("倍速")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 8) {
                ForEach(rateOptions, id: \.self) { r in
                    Button {
                        player.setRate(r)
                    } label: {
                        Text(rateLabel(r))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(player.rate == r
                                          ? AnyShapeStyle(Theme.accentGradient)
                                          : AnyShapeStyle(Color.white.opacity(0.08)))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("定时关闭")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 8) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.accent)
                Text(sleepStatusText)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                Spacer()
                if player.sleepMode != .none {
                    Button("取消") { player.cancelSleep() }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(12)
            .glassCard(cornerRadius: 14)

            Text("按时间")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
            HStack(spacing: 8) {
                ForEach(minuteOptions, id: \.self) { m in
                    Button {
                        player.setSleepTime(m)
                    } label: {
                        Text("\(m)分")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("按集数")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
            HStack(spacing: 8) {
                ForEach(episodeOptions, id: \.self) { n in
                    Button {
                        player.setSleepEpisodes(n)
                    } label: {
                        Text("\(n)集")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var hintCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("小提示", systemImage: "lightbulb.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            Text("定时关闭会在设定时间或集数后自动暂停播放，适合睡前收听。")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 14)
    }

    private var coverThumb: some View {
        Group {
            if let ui = coverImage {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.coverGradient(for: player.currentCollectionKey)
                    Text(firstChar)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
    }

    private func rateLabel(_ r: Float) -> String {
        if r == 1.0 { return "1×" }
        if r == 1.25 { return "1.25×" }
        if r == 1.5 { return "1.5×" }
        if r == 0.75 { return "0.75×" }
        return "2×"
    }

    private var sleepStatusText: String {
        switch player.sleepMode {
        case .none:
            return "未开启"
        case .time:
            return "还剩 \(fmt(Double(player.sleepRemaining)))"
        case .episodes:
            return "再播 \(player.sleepRemaining) 集"
        }
    }
}
