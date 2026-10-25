import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

enum HomeSheet: Identifiable {
    case rename(Collection)
    case cover(Collection)

    var id: String {
        switch self {
        case .rename(let c): return "rename-\(c.id)"
        case .cover(let c): return "cover-\(c.id)"
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
    @State private var sheet: HomeSheet?
    @State private var showFolderImport = false
    @State private var showFileImport = false

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

                    Text("我的合集")
                        .font(.title3).bold()
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
                                    CollectionDetailView(collection: c)
                                } label: {
                                    CollectionCard(collection: c)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        sheet = .rename(c)
                                    } label: {
                                        Label("重命名", systemImage: "pencil")
                                    }
                                    Button {
                                        sheet = .cover(c)
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

                    Button {
                        showFileImport = true
                    } label: {
                        Label("选择音频文件（U 盘/文件，可多选，不复制）", systemImage: "music.note.list")
                    }
                    .padding(.horizontal, 20)

                    Button {
                        showFolderImport = true
                    } label: {
                        Label("从 U 盘 / 文件 选择文件夹（不复制）", systemImage: "externaldrive.badge.plus")
                    }
                    .padding(.horizontal, 20)

                    Button {
                        library.clearImports()
                    } label: {
                        Label("清空外部导入", systemImage: "xmark.circle")
                    }
                    .padding(.horizontal, 20)

                    if !library.importStatus.isEmpty {
                        Text(library.importStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("本地听书")
            .sheet(item: $sheet) { s in
                switch s {
                case .rename(let c):
                    RenameSheet(collection: c).environmentObject(library)
                case .cover(let c):
                    CoverSheet(collection: c).environmentObject(library)
                }
            }
            .fileImporter(
                isPresented: $showFileImport,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    library.importFiles(urls)
                case .failure:
                    break
                }
            }
            .fileImporter(
                isPresented: $showFolderImport,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for u in urls { library.importFolder(u) }
                case .failure:
                    break
                }
            }
            .task { library.scan() }
        }
    }
}

struct HeroCard: View {
    let last: Track
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel

    private var collectionName: String {
        library.collection(forKey: last.collectionKey)?.name ?? "—"
    }

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
                    Text(collectionName).font(.caption2).foregroundStyle(.white.opacity(0.75))
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
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        _ = library.renameCollection(collection, to: name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct CoverSheet: View {
    let collection: Collection
    @EnvironmentObject var library: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var pickedItem: PhotosPickerItem?
    @State private var preview: UIImage?
    @State private var busy = false
    @State private var message = ""

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

                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("从相册选择图片", systemImage: "photo")
                }
                .buttonStyle(.borderedProminent)

                if busy { ProgressView() }

                if !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
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
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
            }
        }
        .onChange(of: pickedItem) { item in
            guard let item = item else { return }
            busy = true
            message = ""
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self),
                          let ui = UIImage(data: data) else {
                        message = "读取图片失败，请换一张试试"
                        busy = false
                        return
                    }
                    preview = ui
                    let jpeg = ui.jpegData(compressionQuality: 0.85) ?? data
                    library.saveCover(jpeg, for: collection)
                    message = "封面已保存"
                } catch {
                    message = "出错：\(error.localizedDescription)"
                }
                busy = false
            }
        }
    }
}
