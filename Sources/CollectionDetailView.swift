import SwiftUI
import UIKit

struct CollectionDetailView: View {
    let collection: Collection
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    coverView
                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.25), radius: 12, y: 6)

                    Text(collection.name).font(.title2).bold()
                    Text("\(collection.tracks.count) 集").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(collection.tracks) { t in
                    Button {
                        player.play(t, queue: collection.tracks)
                    } label: {
                        HStack {
                            Text("\(episodeNumber(t.name) ?? 0)")
                                .frame(width: 32)
                                .foregroundStyle(.secondary)
                            Text(t.name).lineLimit(1)
                            Spacer()
                            if player.title == t.name {
                                Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(collection.name)
    }

    @ViewBuilder private var coverView: some View {
        if let path = library.coverURL(for: collection)?.path, let ui = UIImage(contentsOfFile: path) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            LinearGradient(
                colors: [Color(red: 0.55, green: 0.78, blue: 1.0), Color(red: 0.35, green: 0.52, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                Text(String(collection.name.prefix(1)))
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)
            )
        }
    }
}
