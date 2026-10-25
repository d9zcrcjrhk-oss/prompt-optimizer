import SwiftUI
import UIKit

struct CollectionDetailView: View {
    let collection: Collection
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    coverHeader
                    trackList
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.ink, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(Theme.gold)
    }

    private var coverHeader: some View {
        VStack(spacing: 14) {
            coverView
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Theme.gold.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)

            Text(collection.name)
                .font(Theme.serif(24, .bold))
                .foregroundStyle(Theme.text)

            Text("\(collection.tracks.count) 集")
                .font(Theme.serif(12))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    private var trackList: some View {
        LazyVStack(spacing: 2) {
            ForEach(collection.tracks) { t in
                Button {
                    player.play(t, queue: collection.tracks)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(episodeNumber(t.name) ?? 0)")
                            .font(Theme.serif(12))
                            .foregroundStyle(player.title == t.name ? Theme.gold : Theme.muted)
                            .frame(width: 34, alignment: .trailing)

                        Text(t.name)
                            .font(Theme.serif(15))
                            .foregroundStyle(player.title == t.name ? Theme.gold : Theme.text)
                            .lineLimit(1)

                        Spacer()

                        if player.title == t.name {
                            Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                                .foregroundStyle(Theme.gold)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(player.title == t.name ? Theme.gold.opacity(0.08) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var coverView: some View {
        if let path = library.coverURL(for: collection)?.path,
           let ui = UIImage(contentsOfFile: path) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            ZStack {
                Theme.coverFallback
                Text(String(collection.name.prefix(1)))
                    .font(Theme.serif(70, .bold))
                    .foregroundStyle(Theme.goldSoft.opacity(0.85))
            }
        }
    }
}
