import SwiftUI
import PhotosUI
import UIKit

struct CollectionDetailView: View {
    let collection: Collection
    @Binding var showPlayer: Bool
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
    @Environment(\.dismiss) private var dismiss

    @State private var showRename = false
    @State private var newName = ""
    @State private var pickedItem: PhotosPickerItem?
    @State private var coverTick = 0

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    coverView
                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.25), radius: 12, y: 6)
                        .id(coverTick)

                    Text(collection.name).font(.title2).bold()
                    Text("\(collection.tracks.count) 集").font(.caption).foregroundStyle(.secondary)

                    HStack(spacing: 14) {
                        Button {
                            newName = collection.name
                            showRename = true
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)

                        PhotosPicker(selection: $pickedItem, matching: .images) {
                            Label("设置封面", systemImage: "photo")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(collection.tracks) { t in
                    Button {
                        player.play(t, queue: collection.tracks)
                        showPlayer = true
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
        .alert("重命名合集", isPresented: $showRename) {
            TextField("名称", text: $newName)
            Button("确定") {
                if library.renameCollection(collection, to: newName) {
                    dismiss()
                }
            }
            Button("取消", role: .cancel) {}
        }
        .onChange(of: pickedItem) { item in
            guard let item = item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    library.saveCover(data, for: collection)
                    coverTick += 1
                }
                pickedItem = nil
            }
        }
    }

    @ViewBuilder private var coverView: some View {
        if let path = library.coverURL(for: collection)?.path, let ui = UIImage(contentsOfFile: path) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
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
