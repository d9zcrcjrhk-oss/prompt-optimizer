import SwiftUI
import UIKit

struct EpisodeSheet: View {
    let collection: Collection
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    private var groupStarts: [Int] {
        let n = collection.tracks.count
        guard n > 0 else { return [] }
        return Array(stride(from: 0, to: n, by: 100))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    ForEach(groupStarts, id: \.self) { start in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(rangeTitle(start))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.55))
                                .padding(.horizontal, 20)

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(start..<min(start + 100, collection.tracks.count), id: \.self) { idx in
                                    tile(idx)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.bottom, 34)
            }
            .background(Color.black)
            .navigationTitle("选集")
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

    private var header: some View {
        HStack(spacing: 12) {
            cover
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("共 \(collection.tracks.count) 集")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func rangeTitle(_ start: Int) -> String {
        let end = min(start + 100, collection.tracks.count)
        return "第 \(start + 1)–\(end) 集"
    }

    private func tile(_ idx: Int) -> some View {
        let t = collection.tracks[idx]
        let isCurrent = player.title == t.name

        return Button {
            player.play(t, queue: collection.tracks)
            dismiss()
        } label: {
            Text("\(idx + 1)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isCurrent ? Color.white : Color.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    Group {
                        if isCurrent {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.accentGradient)
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var cover: some View {
        if let path = library.coverURL(for: collection)?.path,
           let ui = UIImage(contentsOfFile: path) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            ZStack {
                Theme.coverGradient(for: collection.id)
                Text(String(collection.name.prefix(1)))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }
}
