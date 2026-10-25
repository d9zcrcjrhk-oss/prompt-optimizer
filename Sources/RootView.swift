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

    private static let quotes = [
        "把故事，听成自己的。",
        "夜读 · 声里藏卷。",
        "一页一页，听进心里。",
        "书声入梦来。",
        "灯火可亲，书声可听。"
    ]
    @State private var quote = HomeView.quotes.randomElement() ?? "把故事，听成自己的。"

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if let last = library.lastTrack {
                        HeroCard(last: last) { tab = .playing }
                    }

                    sectionTitle("书架", "\(library.collections.count) 卷")

                    if library.collections.isEmpty {
                        emptyState
                    } else {
                        grid
                    }

                    actions
                }
                .padding(.bottom, 36)
            }
            .background(Theme.background)
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
        .tint(Theme.gold)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("本地听书")
                .font(Theme.serif(30, .bold))
                .foregroundStyle(Theme.text)
            Text(quote)
                .font(Theme.serif(13))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private func sectionTitle(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Theme.serif(18, .semibold)).foregroundStyle(Theme.text)
            Spacer()
            Text(detail).font(Theme.serif(11)).foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 22)
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 20) {
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
        .padding(.horizontal, 22)
        .id(library.coverRevision)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 38))
                .foregroundStyle(Theme.gold.opacity(0.5))
            Text("书架还空着")
                .font(Theme.serif(16, .semibold))
                .foregroundStyle(Theme.text)
            Text("把音频文件夹放进「文件」App → 我的 iPhone → 本地听书，再点「重新扫描」。")
                .font(Theme.serif(12))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                library.scan()
            } label: {
                Label("重新扫描", systemImage: "arrow.clockwise")
                    .font(Theme.serif(13))
                    .foregroundStyle(Theme.gold)
            }

            Text("长按合集，可重命名或换封面。")
                .font(Theme.serif(11))
                .foregroundStyle(Theme.muted.opacity(0.85))

            if !library.importStatus.isEmpty {
                Text(library.importStatus)
                    .font(Theme.serif(11))
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .padding(.top, 4)
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
                    .frame(height: 190)
                    .frame(maxWidth: .infinity)

                LinearGradient(
                    colors: [.clear, Theme.ink.opacity(0.5), Theme.ink.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text("续 · 昨夜未听完的")
                        .font(Theme.serif(11))
                        .foregroundStyle(Theme.goldSoft)
                    Text(last.name)
                        .font(Theme.serif(19, .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(collection?.name ?? "—")
                        .font(Theme.serif(11))
                        .foregroundStyle(Theme.muted)
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(alignment: .topTrailing) { playBadge.padding(16) }
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.gold.opacity(0.25), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 20, y: 12)
            .padding(.horizontal, 22)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var heroCover: some View {
        if let c = collection,
           let path = library.coverURL(for: c)?.path,
           let ui = UIImage(contentsOfFile: path) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            Theme.coverFallback
        }
    }

    private var playBadge: some View {
        ZStack {
            Circle().fill(Theme.gold).frame(width: 46, height: 46)
            Image(systemName: "play.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.ink)
        }
    }
}

struct CollectionCard: View {
    let collection: Collection
    @EnvironmentObject var library: LibraryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                cover
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.gold.opacity(0.16), lineWidth: 1)
                    )

                Text("\(collection.tracks.count)")
                    .font(Theme.serif(11, .semibold))
                    .foregroundStyle(Theme.goldSoft)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
                    .padding(8)
            }

            Text(collection.name)
                .font(Theme.serif(14, .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
        }
    }

    @ViewBuilder private var cover: some View {
        if let path = library.coverURL(for: collection)?.path,
           let ui = UIImage(contentsOfFile: path) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            ZStack {
                Theme.coverFallback
                Text(String(collection.name.prefix(1)))
                    .font(Theme.serif(40, .bold))
                    .foregroundStyle(Theme.goldSoft.opacity(0.85))
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
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Text("重命名")
                    .font(Theme.serif(20, .semibold))
                    .foregroundStyle(Theme.text)

                TextField("输入新名称", text: $name)
                    .font(Theme.serif(16))
                    .foregroundStyle(Theme.text)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.gold.opacity(0.2), lineWidth: 1))

                HStack {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Button("保存") {
                        _ = library.renameCollection(collection, to: name)
                        dismiss()
                    }
                    .foregroundStyle(Theme.gold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .font(Theme.serif(15, .semibold))
                .padding(.top, 4)

                Spacer()
            }
            .padding(24)
        }
        .presentationDetents([.height(230)])
        .preferredColorScheme(.dark)
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
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("设置封面")
                        .font(Theme.serif(20, .semibold))
                        .foregroundStyle(Theme.text)
                    Text(collection.name)
                        .font(Theme.serif(12))
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Group {
                    if let ui = preview {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else if let path = library.coverURL(for: collection)?.path,
                              let ui = UIImage(contentsOfFile: path) {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else {
                        ZStack {
                            Theme.coverFallback
                            Text(String(collection.name.prefix(1)))
                                .font(Theme.serif(64, .bold))
                                .foregroundStyle(Theme.goldSoft.opacity(0.85))
                        }
                    }
                }
                .frame(width: 190, height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.gold.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)

                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("从相册选择图片", systemImage: "photo")
                        .font(Theme.serif(14))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.gold)
                .foregroundStyle(Theme.ink)

                if busy { ProgressView().tint(Theme.gold) }

                if !message.isEmpty {
                    Text(message)
                        .font(Theme.serif(11))
                        .foregroundStyle(message.contains("已保存") ? Theme.gold : .red)
                }

                Text("封面会保存到该合集的文件夹里，下次打开仍然有效。")
                    .font(Theme.serif(10))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
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
