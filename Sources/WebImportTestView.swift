import SwiftUI
import WebKit

/// 常驻网页：持有用户选中的文件，按需逐集取字节
final class WebSource: NSObject, ObservableObject, WKScriptMessageHandler {
    static let shared = WebSource()

    @Published var files: [(name: String, size: Int)] = []
    @Published var alive = false

    private var web: WKWebView?
    private var curIndex = -1
    private var curHandle: FileHandle?
    private var curURL: URL?
    private var curProgress: ((Double) -> Void)?
    private var curCompletion: ((URL?) -> Void)?
    private var curTotal = 0
    private var curReceived = 0

    func ensureWebView() -> WKWebView {
        if let w = web { return w }
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(self, name: "ws")
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.backgroundColor = .black
        w.isOpaque = false
        w.loadHTMLString(Self.html, baseURL: nil)
        web = w
        return w
    }

    func fetch(index: Int, progress: ((Double) -> Void)?, completion: @escaping (URL?) -> Void) {
        guard alive, let w = web, index >= 0, index < files.count else {
            completion(nil)
            return
        }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("wfetch-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: tmp.path, contents: nil)
        curURL = tmp
        curHandle = try? FileHandle(forWritingTo: tmp)
        curIndex = index
        curTotal = files[index].size
        curReceived = 0
        curProgress = progress
        curCompletion = completion
        DispatchQueue.main.async {
            w.evaluateJavaScript("window.startRead(\(index));", completionHandler: nil)
        }
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let d = message.body as? [String: Any], let kind = d["kind"] as? String else { return }
        switch kind {
        case "picked":
            let arr = d["files"] as? [[String: Any]] ?? []
            files = arr.map { (($0["name"] as? String) ?? "audio", ($0["size"] as? Int) ?? 0) }
            alive = true

        case "chunk":
            guard let idx = d["index"] as? Int, idx == curIndex,
                  let b64 = d["data"] as? String,
                  let raw = Data(base64Encoded: b64),
                  let h = curHandle else { return }
            h.write(raw)
            curReceived += raw.count
            curProgress?(curTotal > 0 ? min(1, Double(curReceived) / Double(curTotal)) : 0)

        case "readDone":
            guard let idx = d["index"] as? Int, idx == curIndex else { return }
            curHandle?.closeFile()
            curHandle = nil
            let u = curURL
            curURL = nil
            curCompletion?(u)
            curCompletion = nil
            curIndex = -1

        case "readError":
            curHandle?.closeFile()
            curHandle = nil
            curCompletion?(nil)
            curCompletion = nil
            curIndex = -1

        default:
            break
        }
    }

    static let html: String = #"""
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<style>
  body { background:#000; color:#fff; font-family:-apple-system; padding:20px; margin:0; }
  h1 { font-size:22px; margin:4px 0 16px; }
  button { display:block; width:100%; padding:16px; border-radius:14px; border:none;
           background:#fff; color:#000; font-size:17px; font-weight:600; }
  .tip { margin-top:16px; color:#666; font-size:12px; line-height:1.7; }
  input[type=file] { display:none; }
</style>
</head>
<body>
<h1>选择音频</h1>
<button id="pick">选择音频文件（可多选）</button>
<input type="file" id="input" multiple>
<p class="tip">选中后先建合集，只下载前 2 集；之后边听边下、听完即删。</p>
<script>
var picked = [];
function send(o) { try { window.webkit.messageHandlers.ws.postMessage(o); } catch (e) {} }
document.getElementById('pick').onclick = function () { document.getElementById('input').click(); };
document.getElementById('input').addEventListener('change', function (e) {
  picked = Array.prototype.slice.call(e.target.files || []);
  send({ kind: 'picked', files: picked.map(function (f) { return { name: f.name, size: f.size }; }) });
  document.getElementById('pick').textContent = '已选 ' + picked.length + ' 个（可重新选择）';
});
window.startRead = async function (i) {
  var f = picked[i];
  if (!f) { send({ kind: 'readError', index: i }); return; }
  var CHUNK = 1024 * 1024;
  var total = Math.ceil(f.size / CHUNK) || 1;
  for (var seq = 0; seq < total; seq++) {
    var start = seq * CHUNK, end = Math.min(f.size, start + CHUNK);
    var buf = await f.slice(start, end).arrayBuffer();
    var bytes = new Uint8Array(buf);
    var bin = '', step = 0x8000;
    for (var p = 0; p < bytes.length; p += step) {
      bin += String.fromCharCode.apply(null, bytes.subarray(p, p + step));
    }
    send({ kind: 'chunk', index: i, seq: seq, total: total, data: btoa(bin) });
    await new Promise(function (r) { setTimeout(r, 0); });
  }
  send({ kind: 'readDone', index: i });
};
</script>
</body>
</html>
"""#
}

struct WebSourceWebView: UIViewRepresentable {
    let web: WKWebView
    func makeUIView(context: Context) -> WKWebView { web }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct WebImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var library: LibraryModel
    @ObservedObject private var ws = WebSource.shared
    @State private var mode = 0
    @State private var newName = ""
    @State private var existingId = ""
    @State private var importing = false
    @State private var progress: Double = 0
    @State private var statusText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                WebSourceWebView(web: ws.ensureWebView())
                    .ignoresSafeArea()

                if !ws.files.isEmpty {
                    chooser
                        .background(Color.black)
                }
            }
            .background(Color.black)
            .navigationTitle("导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .onAppear {
            if existingId.isEmpty, let first = library.collections.first {
                existingId = first.id
            }
        }
    }

    private var chooser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.accent)
                    Text("已选 \(ws.files.count) 个文件")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                }

                if importing {
                    Text(statusText)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                    ProgressView(value: progress)
                        .tint(Theme.accent)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("这些文件要怎么放？").font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
                        Picker("方式", selection: $mode) {
                            Text("制作合集").tag(0)
                            Text("已有合集").tag(1)
                            Text("不形成合集").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }

                    if mode == 0 {
                        TextField("合集名称", text: $newName)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                            .foregroundStyle(.white)
                        Text("制作合集：只下载前 2 集，之后边听边下、听完即删。")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                    } else if mode == 1 {
                        if library.collections.isEmpty {
                            Text("还没有合集").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                        } else {
                            Picker("合集", selection: $existingId) {
                                ForEach(library.collections) { c in
                                    Text(c.name).tag(c.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.accent)
                        }
                        Text("已有合集：会下载全部选中文件。")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                    } else {
                        Text("不形成合集：会下载全部选中文件到「未归类」。")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    Button {
                        let placement: WebPlacement
                        switch mode {
                        case 0: placement = .newCollection(newName)
                        case 1: placement = .existing(existingId)
                        default: placement = .loose
                        }
                        startImport(placement)
                    } label: {
                        Text("导入")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accentGradient))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(20)
        }
    }

    private func startImport(_ placement: WebPlacement) {
        let target = library.prepareWebImport(placement)
        let total = ws.files.count
        let count = target.lazy ? min(2, total) : total

        if target.lazy {
            let eps = ws.files.map { WebEpisode(name: $0.name, size: $0.size, downloaded: false) }
            library.saveWebEpisodes(target.id, eps)
        }

        importing = true
        statusText = "下载 1/\(count)…"
        download(index: 0, count: count, id: target.id, dir: target.dir, lazy: target.lazy)
    }

    private func download(index: Int, count: Int, id: String, dir: URL, lazy: Bool) {
        guard index < count, index < ws.files.count else {
            library.scan()
            dismiss()
            return
        }
        statusText = "下载 \(index + 1)/\(count)…"
        let name = ws.files[index].name
        ws.fetch(index: index, progress: { p in
            progress = (Double(index) + p) / Double(count)
        }) { url in
            if let url = url {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let dest = dir.appendingPathComponent(name)
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.moveItem(at: url, to: dest)
                if lazy {
                    var eps = library.loadWebEpisodes(id)
                    if let i = eps.firstIndex(where: { $0.name == name }) {
                        eps[i].downloaded = true
                        library.saveWebEpisodes(id, eps)
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                download(index: index + 1, count: count, id: id, dir: dir, lazy: lazy)
            }
        }
    }
}
