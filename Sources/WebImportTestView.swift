import SwiftUI
import WebKit

struct ReceivedFile: Identifiable {
    let id = UUID()
    let name: String
    let size: Int
    var url: URL
}

final class WebImportModel: NSObject, ObservableObject, WKScriptMessageHandler {
    @Published var files: [ReceivedFile] = []
    @Published var status = "等待选择…"
    @Published var progress: Double = 0
    @Published var finished = false
    @Published var failed: String?

    private var handles: [Int: FileHandle] = [:]
    private var received: [Int: Int] = [:]
    private var totalBytes = 0
    private var tempDir: URL?

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let kind = dict["kind"] as? String else { return }

        switch kind {
        case "files":
            let arr = dict["files"] as? [[String: Any]] ?? []
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("webimport-\(UUID().uuidString)", isDirectory: true)
            tempDir = dir
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            var list: [ReceivedFile] = []
            for (i, f) in arr.enumerated() {
                let name = (f["name"] as? String) ?? "audio-\(i)"
                let size = (f["size"] as? Int) ?? 0
                let url = dir.appendingPathComponent("\(i)-\(name)")
                FileManager.default.createFile(atPath: url.path, contents: nil)
                handles[i] = try? FileHandle(forWritingTo: url)
                received[i] = 0
                list.append(ReceivedFile(name: name, size: size, url: url))
            }
            totalBytes = list.reduce(0) { $0 + $1.size }
            files = list
            status = "接收中…"

        case "chunk":
            guard let file = dict["file"] as? Int,
                  let b64 = dict["data"] as? String,
                  let handle = handles[file],
                  let raw = Data(base64Encoded: b64) else { return }
            handle.write(raw)
            received[file, default: 0] += raw.count
            let r = received.values.reduce(0, +)
            progress = totalBytes > 0 ? min(1, Double(r) / Double(totalBytes)) : 0

        case "fileDone":
            guard let file = dict["file"] as? Int else { return }
            handles[file]?.closeFile()
            handles[file] = nil

        case "allDone":
            progress = 1
            status = "接收完成"
            finished = true

        case "error":
            failed = dict["error"] as? String
            status = "出错"

        default:
            break
        }
    }
}

struct WebImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var library: LibraryModel
    @StateObject private var model = WebImportModel()
    @State private var mode = 0
    @State private var newName = ""
    @State private var existingId = ""

    var body: some View {
        NavigationStack {
            Group {
                if model.finished {
                    placementChooser
                } else {
                    VStack(spacing: 0) {
                        WebImportWebView(model: model)
                        progressBar
                    }
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
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.status)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("\(Int(model.progress * 100))%")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            ProgressView(value: model.progress)
                .tint(Theme.accent)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
    }

    private var placementChooser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.accent)
                    Text("已接收 \(model.files.count) 个文件")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.files.prefix(5)) { f in
                        Text("· \(f.name)")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    if model.files.count > 5 {
                        Text("… 还有 \(model.files.count - 5) 个")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("这些文件要怎么放？")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))

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
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                } else if mode == 1 {
                    if library.collections.isEmpty {
                        Text("还没有合集，请选「制作合集」")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        Picker("合集", selection: $existingId) {
                            ForEach(library.collections) { c in
                                Text(c.name).tag(c.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                    }
                } else {
                    Text("文件会放进「未归类」里")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Button {
                    let placement: WebPlacement
                    switch mode {
                    case 0: placement = .newCollection(newName)
                    case 1: placement = .existing(existingId)
                    default: placement = .loose
                    }
                    _ = library.importWebFiles(model.files, placement: placement)
                    dismiss()
                } label: {
                    Text("导入")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accentGradient))
                }
                .buttonStyle(.plain)

                Button("取消") { dismiss() }
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding(20)
        }
        .onAppear {
            if existingId.isEmpty, let first = library.collections.first {
                existingId = first.id
            }
        }
    }
}

struct WebImportWebView: UIViewRepresentable {
    let model: WebImportModel

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(model, name: "imp")
        let web = WKWebView(frame: .zero, configuration: config)
        web.backgroundColor = .black
        web.isOpaque = false
        web.loadHTMLString(Self.html, baseURL: nil)
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static let html: String = #"""
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<style>
  body { background:#000; color:#fff; font-family:-apple-system; padding:20px; margin:0; }
  h1 { font-size:22px; margin:4px 0 2px; }
  p.sub { color:#888; font-size:13px; margin:0 0 18px; }
  button { display:block; width:100%; padding:16px; margin:0; border-radius:14px;
           background:#fff; color:#000; font-size:17px; font-weight:600; border:none; }
  input[type=file] { display:none; }
  .tip { margin-top:18px; color:#666; font-size:12px; line-height:1.7; }
</style>
</head>
<body>
<h1>选择音频</h1>
<p class="sub">可多选，选中后会自动传到 App</p>

<button id="pick">选择音频文件（可多选）</button>
<input type="file" id="input" multiple>

<p class="tip">提示：本页只能选择「文件」，无法选择整个文件夹。选完后 App 会问你要怎么归类。</p>

<script>
var CHUNK = 1024 * 1024;

function send(obj) {
  try { window.webkit.messageHandlers.imp.postMessage(obj); } catch (e) {}
}

document.getElementById('pick').addEventListener('click', function () {
  document.getElementById('input').click();
});

document.getElementById('input').addEventListener('change', async function (e) {
  var files = Array.prototype.slice.call(e.target.files || []);
  if (files.length === 0) { return; }

  send({
    kind: 'files',
    files: files.map(function (f) { return { name: f.name, size: f.size }; })
  });

  for (var i = 0; i < files.length; i++) {
    var f = files[i];
    var total = Math.ceil(f.size / CHUNK) || 1;
    for (var seq = 0; seq < total; seq++) {
      var start = seq * CHUNK;
      var end = Math.min(f.size, start + CHUNK);
      try {
        var buf = await f.slice(start, end).arrayBuffer();
        var bytes = new Uint8Array(buf);
        var bin = '';
        var step = 0x8000;
        for (var p = 0; p < bytes.length; p += step) {
          bin += String.fromCharCode.apply(null, bytes.subarray(p, p + step));
        }
        send({ kind: 'chunk', file: i, seq: seq, total: total, data: btoa(bin) });
      } catch (err) {
        send({ kind: 'error', error: String(err) });
        return;
      }
      await new Promise(function (r) { setTimeout(r, 0); });
    }
    send({ kind: 'fileDone', file: i });
  }

  send({ kind: 'allDone' });
  document.getElementById('pick').textContent = '已选 ' + files.length + ' 个（可再次选择）';
});
</script>
</body>
</html>
"""#
}
