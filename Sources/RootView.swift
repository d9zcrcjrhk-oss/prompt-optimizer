import SwiftUI
import UIKit
import PhotosUI

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
    @Binding var tab: MainTab
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel
    @State private var sheet: HomeSheet?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var totalEpisodes: Int {
        library.collections.reduce(0) { $0 + $1.tracks.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if let last = library.lastTrack {
                        HeroCard(last: last) { tab = .playing }
                    } else {
                        startPrompt
                    }

                    if !player.recent.isEmpty {
                        sectionTitle("最近聆听", "\(player.recent.count)")
                        recentRow
                    }

                    sectionTitle("全部合集", "\(library.collections.count) 部")
                    if library.collections.isEmpty {
                        emptyState
                    } else {
                        grid
                    }

                    actions
                }
                .padding(.bottom, 30)
            }
            .background(Theme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $sheet) { s in
                switch s {
                case .rename(let c):
                    RenameSheet(collection: c).environmentObject(library)
                case .cover(let c):
                    CoverSheet(collection: c).environmentObject(library)
                }
            }
            .task { library.scan() }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("我的书架")
                    .font(Theme.serif(28, .bold))
                    .foregroundStyle(Theme.text)
                Text("共 \(library.collections.count) 部 · \(totalEpisodes) 集")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "headphones")
                .font(.system(size: 22))
                .foregroundStyle(Theme.accent)
                .padding(10)
                .background(Circle().fill(Theme.accentSoft))
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func sectionTitle(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Theme.serif(17, .semibold)).foregroundStyle(Theme.text)
            Spacer()
            Text(detail).font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 20)
    }

    private var recentRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(player.recent) { t in
                    Button {
                        player.play(t, queue: library.queue(for: t))
                        tab = .playing
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            coverTile(for: t)
                                .frame(width: 84, height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                )
                            Text(t.name)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                                .frame(width: 84, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func coverTile(for t: Track) -> some View {
        Group {
            if let c = library.collection(forKey: t.collectionKey),
               let path = library.coverURL(for: c)?.path,
               let ui = UIImage(contentsOfFile: path) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.coverGradient(for: t.collectionKey)
                    Text(String((library.collection(forKey: t.collectionKey)?.name ?? "?").prefix(1)))
                        .font(Theme.serif(28, .bold))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
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

    private var startPrompt: some View {
        Button {
            tab = .playing
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.accentSoft).frame(width: 52, height: 52)
                    Image(systemName: "play.fill").foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("开始聆听").font(Theme.serif(16, .semibold)).foregroundStyle(Theme.text)
                    Text("选一个合集，从第一集开始。").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accent.opacity(0.15), lineWidth: 1))
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "book.closed")
                .font(.system(size: 34))
                .foregroundStyle(Theme.accent.opacity(0.5))
            Text("书架还空着").font(Theme.serif(15, .semibold)).foregroundStyle(Theme.text)
            Text("把音频文件夹放进「文件」App → 我的 iPhone → 本地听书，再点「重新扫描」。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 30)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                library.scan()
            } label: {
                Label("重新扫描", systemImage: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }

            Text("长按合集可重命名 / 换封面")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)

            if !library.importStatus.isEmpty {
                Text(library.importStatus)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .padding(.top, 6)
    }
}

struct HeroCard: View {
    let last: Track
    let onPlayed: () -> Void
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel

    private var collection: Collection? {
        library.collection(forKey: last.collectionKey)
    }

    var body: some View {
        Button {
            player.play(last, queue: library.queue(for: last))
            onPlayed()
        } label: {
            ZStack(alignment: .bottomLeading) {
                heroCover
                    .frame(height: 168)
                    .frame(maxWidth: .infinity)

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.45), Color.black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("继续上次")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(last.name)
                        .font(Theme.serif(18, .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(collection?.name ?? "—")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(alignment: .topTrailing) { playBadge.padding(14) }
            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var heroCover: some View {
        if let c = collection,
           let path = library.coverURL(for: c)?.path,
           let ui = UIImage(contentsOfFile: path) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            Theme.coverGradient(for: last.collectionKey)
        }
    }

    private var playBadge: some View {
        ZStack {
            Circle().fill(.white.opacity(0.22)).frame(width: 40, height: 40)
            Image(systemName: "play.fill")
                .font(.system(size: 15))
                .foregroundStyle(.white)
        }
    }
}

struct CollectionCard: View {
    let collection: Collection
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var library: LibraryModel

    private var isCurrent: Bool {
        player.currentCollectionKey == collection.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            cover
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .overlay(alignment: .bottomLeading) {
                    if !(isCurrent && player.duration > 0) {
                        Text("\(collection.tracks.count) 集")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.black.opacity(0.35)))
                            .padding(8)
                    }
                }
                .overlay(alignment: .bottom) {
                    if isCurrent && player.duration > 0 {
                        ProgressView(value: player.current, total: max(player.duration, 1))
                            .tint(Theme.accent)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                    }
                }

            Text(collection.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Text("\(collection.tracks.count) 集")
                .font(.system(size: 10))
                .foregroundStyle(Theme.muted)
        }
    }

    @ViewBuilder private var cover: some View {
        if let path = library.coverURL(for: collection)?.path,
           let ui = UIImage(contentsOfFile: path) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            ZStack {
                Theme.coverGradient(for: collection.id)
                Text(String(collection.name.prefix(1)))
                    .font(Theme.serif(38, .bold))
                    .foregroundStyle(.white.opacity(0.92))
            }
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
            VStack(spacing: 18) {
                Group {
                    if let ui = preview {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else if let path = library.coverURL(for: collection)?.path,
                              let ui = UIImage(contentsOfFile: path) {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else {
                        ZStack {
                            Theme.coverGradient(for: collection.id)
                            Text(String(collection.name.prefix(1)))
                                .font(Theme.serif(60, .bold))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                    }
                }
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 8)

                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("从相册选择图片", systemImage: "photo")
                }
                .buttonStyle(.borderedProminent)

                if busy { ProgressView() }

                if !message.isEmpty {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(message.contains("已保存") ? Theme.accent : .red)
                }

                Text("封面会保存到该合集的文件夹里，下次打开仍然有效。")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(24)
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
