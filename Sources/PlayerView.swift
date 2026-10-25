import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var player: PlayerModel
    @Environment(\.dismiss) private var dismiss

    @State private var sleepMode = 0
    @State private var sleepMinutes = 30
    @State private var sleepEpisodes = 3

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("收起") { dismiss() }
                Spacer()
            }

            Spacer(minLength: 6)

            Text(player.title)
                .font(.title2)
                .bold()
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Spacer(minLength: 6)

            if player.duration > 0 {
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { player.current },
                            set: { player.seek(to: $0) }
                        ),
                        in: 0...max(player.duration, 1)
                    )
                    HStack {
                        Text(fmt(player.current)).font(.caption)
                        Spacer()
                        Text(fmt(player.duration)).font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 22) {
                Button { player.seek(to: max(0, player.current - 15)) } label: {
                    Image(systemName: "gobackward.15")
                }
                Button { player.prev() } label: {
                    Image(systemName: "backward.end.fill")
                }
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                }
                Button { player.next() } label: {
                    Image(systemName: "forward.end.fill")
                }
                Button { player.seek(to: player.current + 15) } label: {
                    Image(systemName: "goforward.15")
                }
            }
            .font(.title2)

            HStack(spacing: 8) {
                Text("倍速").font(.caption).foregroundStyle(.secondary)
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

            VStack(alignment: .leading, spacing: 10) {
                Text("定时关闭").font(.headline)

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
                    Text(sleepStatus).font(.caption).foregroundStyle(.orange)
                    Button("取消定时", role: .destructive) { player.cancelSleep() }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.secondary.opacity(0.12))
            )

            Spacer()
        }
        .padding()
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
