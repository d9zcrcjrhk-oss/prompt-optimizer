import SwiftUI
import UIKit
import PhotosUI

struct RootView: View {
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
    @State private var showPlayer = false
    @State private var renameTarget: Collection?
    @State private var coverTarget: Collection?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let last = library.lastTrack {
                        HeroCard(last: last)
                    }

                    HStack {
                        Text("我的合集").font(.title3).bold()
                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    if library.collections.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "folder.badge.plus")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("还没有音频").font(.headline)
                            Text("把音频文件夹放进「文件」App → 我的 iPhone → 本地听书，再点下面的重新扫描。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(30)
                    } else {
                        Text("长按合集卡片可重命名 / 换封面")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)

                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(library.collections) { c in
                                NavigationLink {
                                    CollectionDetailView(collection: c, showPlayer: $showPlayer)
                                } label: {
                                    CollectionCard(collection: c)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        renameTarget = c
                                    } label: {
                                        Label("重命名", systemImage: "pencil")
                                    }
                                    Button {
                                        coverTarget = c
                                    } label: {
                                        Label("设置封面", systemImage: "photo")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .id(library.coverRevision)
                    }

                    Button {
                        library.scan()
                    } label: {
                        Label("重新扫描", systemImage: "arrow.clockwise")
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("本地听书")
            .safeAreaInset(edge: .bottom) {
                if player.hasTrack {
                    MiniBar(showPlayer: $showPlayer)
                }
            }
            .sheet(isPresented: $showPlayer) {
                PlayerView().environmentObject(player)
            }
            .sheet(item: $renameTarget) { c in
                RenameSheet(collection: c)
                    .environmentObject(library)
            }
            .sheet(item: $coverTarget) { c in
                CoverSheet(collection: c)
                    .environmentObject(library)
            }
            .task { library.scan() }
        }
    }
}

struct HeroCard: View {
    let last: Track
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel

    var body: some View {
        Button {
            player.play(last, queue: library.queue(for: last))
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 4) {
                    Text("继续上次").font(.caption).foregroundStyle(.white.opacity(0.8))
                    Text(last.name).font(.headline).foregroundStyle(.white).lineLimit(1)
                    Text(last.collection).font(.caption2).foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.30, green: 0.55, blue: 0.98), Color(red: 0.55, green: 0.35, blue: 0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.2), radius: 10, y: 6)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }
}

struct CollectionCard: View {
    let collection: Collection
    @EnvironmentObject var library: LibraryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            Text(collection.name).font(.subheadline).bold().lineLimit(1).foregroundStyle(.primary)
            Text("\(collection.tracks.count) 集").font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var cover: some View {
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
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.white)
            )
        }
    }
}

// MARK: - 重命名表单（真正可输入）
struct RenameSheet: View {
    let collection: Collection
    @EnvironmentObject var library: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(collection: Collection) {
        self.collection = collection
        _name = State(initialValue: collection.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("合集名称") {
                    TextField("输入新名称", text: $name)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("重命名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if library.renameCollection(collection, to: name) {
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - 封面选择（相册，带预览）
struct CoverSheet: View {
    let collection: Collection
    @EnvironmentObject var library: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var pickedItem: PhotosPickerItem?
    @State private var preview: UIImage?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Group {
                    if let ui = preview {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else if let path = library.coverURL(for: collection)?.path, let ui = UIImage(contentsOfFile: path) {
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
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.2), radius: 10, y: 6)

                PhotosPicker(selection: $pickedItem, matching: .images, photoLibrary: .shared()) {
                    Label("从相册选择图片", systemImage: "photo")
                }
                .buttonStyle(.borderedProminent)

                if busy {
                    ProgressView()
                }

                Text("封面会保存到该合集的文件夹里，下次打开仍然有效。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("设置封面")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .onChange(of: pickedItem) { item in
            guard let item = item else { return }
            busy = true
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    preview = ui
                    let jpeg = ui.jpegData(compressionQuality: 0.85) ?? data
                    library.saveCover(jpeg, for: collection)
                }
                busy = false
            }
        }
    }
}

struct MiniBar: View {
    @EnvironmentObject var player: PlayerModel
    @Binding var showPlayer: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading) {
                Text(player.title).font(.footnote).lineLimit(1)
                Text(player.isPlaying ? "播放中" : "已暂停").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
            }
            Button {
                player.next()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title3)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .contentShape(Rectangle())
        .onTapGesture { showPlayer = true }
    }
}
