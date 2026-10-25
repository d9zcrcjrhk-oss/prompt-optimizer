import SwiftUI
import UIKit

enum MainTab {
    case home
    case playing
}

struct MainView: View {
    @State private var tab: MainTab = .home

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    if tab == .home {
                        HomeView(tab: $tab)
                    } else {
                        NowPlayingView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                BottomBar(tab: $tab)
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.gold)
    }
}

struct BottomBar: View {
    @Binding var tab: MainTab

    var body: some View {
        HStack(spacing: 0) {
            Button {
                tab = .home
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "books.vertical.fill").font(.system(size: 19))
                    Text("书架").font(Theme.serif(10))
                }
                .foregroundStyle(tab == .home ? Theme.gold : Theme.muted)
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
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down").font(.system(size: 19))
                    Text("导入").font(Theme.serif(10))
                }
                .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.inkSoft.opacity(0.94))
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.gold.opacity(0.14)).frame(height: 0.5)
        }
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
            coverContent

            Circle()
                .stroke(Theme.gold.opacity(0.55), lineWidth: 1.2)

            Circle()
                .fill(Theme.gold)
                .frame(width: 5, height: 5)
        }
        .frame(width: 48, height: 48)
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
                Theme.surface
                Text(String(c.name.prefix(1)))
                    .font(Theme.serif(18, .semibold))
                    .foregroundStyle(Theme.goldSoft)
            }
        } else {
            ZStack {
                Theme.surface
                Image(systemName: "music.note").foregroundStyle(Theme.muted)
            }
        }
    }

    private var currentCollection: Collection? {
        guard !player.currentCollectionKey.isEmpty else { return nil }
        return library.collections.first { $0.id == player.currentCollectionKey }
    }
}
