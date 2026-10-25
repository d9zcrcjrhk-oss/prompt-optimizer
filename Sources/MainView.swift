import SwiftUI
import UIKit

enum MainTab {
    case home
    case playing
}

struct MainView: View {
    @State private var tab: MainTab = .home

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if tab == .home {
                    HomeView()
                } else {
                    NowPlayingView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomBar(tab: $tab)
        }
        .background(Color(uiColor: .systemBackground))
    }
}

struct BottomBar: View {
    @Binding var tab: MainTab

    var body: some View {
        HStack(alignment: .center) {
            Button {
                tab = .home
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "house.fill").font(.system(size: 20))
                    Text("首页").font(.caption2)
                }
                .foregroundStyle(tab == .home ? Color.accentColor : Color.secondary)
            }
            .frame(maxWidth: .infinity)

            Button {
                tab = .playing
            } label: {
                SpinningCover()
            }
            .frame(maxWidth: .infinity)

            Button {
                openFilesApp()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "folder.fill").font(.system(size: 20))
                    Text("导入").font(.caption2)
                }
                .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }
}

func openFilesApp() {
    if let url = URL(string: "shareddocuments://") {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

struct SpinningCover: View {
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
    @State private var spin = false

    var body: some View {
        ZStack {
            if let c = currentCollection,
               let path = library.coverURL(for: c)?.path,
               let ui = UIImage(contentsOfFile: path) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else if let c = currentCollection {
                LinearGradient(
                    colors: [Color(red: 0.55, green: 0.78, blue: 1.0), Color(red: 0.35, green: 0.52, blue: 0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Text(String(c.name.prefix(1)))
                        .font(.headline)
                        .foregroundStyle(.white)
                )
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.18))
                    .overlay(
                        Image(systemName: "music.note").foregroundStyle(.secondary)
                    )
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
        .rotationEffect(.degrees(spin ? 360 : 0))
        .animation(spin ? Animation.linear(duration: 6).repeatForever(autoreverses: false) : .default, value: spin)
        .onAppear { spin = player.isPlaying }
        .onChange(of: player.isPlaying) { playing in spin = playing }
    }

    private var currentCollection: Collection? {
        guard !player.currentCollectionKey.isEmpty else { return nil }
        return library.collections.first { $0.id == player.currentCollectionKey }
    }
}
