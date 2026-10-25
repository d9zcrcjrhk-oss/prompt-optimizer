import SwiftUI
import UIKit

struct CollectionDetailView: View {
    let collection: Collection
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                trackList
            }
            .padding(.bottom, 30)
        }
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 12) {
            coverView
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 18, y: 10)

            Text(collection.name)
                .font(Theme.serif(22, .bold))
                .foregroundStyle(Theme.text)

            Text("\(collection.tracks.count) 集")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .padding(.bottom, 20)
    }

    private var trackList: some View {
        LazyVStack(spacing: 2) {
            ForEach(collection.tracks) { t in
                Button {
                    player.play(t, queue: collection.tracks)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(episodeNumber(t.name) ?? 0)")
                            .font(.system(size: 12))
                            .foregroundStyle(player.title == t.name ? Theme.accent : Theme.muted)
                            .frame(width: 34, alignment: .trailing)

                        Text(t.name)
                            .font(.system(size: 15))
                            .foregroundStyle(player.title == t.name ? Theme.accent : Theme.text)
                            .lineLimit(1)

                        Spacer()

                        if player.title == t.name {
                            Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(player.title == t.name ? Theme.accent.opacity(0.14) : Color.white.opacity(0.0))
                    )
                    .padding(.horizontal, 8)
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
                Theme.coverGradient(for: collection.id)
                Text(String(collection.name.prefix(1)))
                    .font(Theme.serif(64, .bold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }
}
