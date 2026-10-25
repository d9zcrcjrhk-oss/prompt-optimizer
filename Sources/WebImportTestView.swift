import SwiftUI
import WebKit

final class WebBridge: NSObject, ObservableObject, WKScriptMessageHandler {
    @Published var logs: [String] = []

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any] else {
            logs.append(String(describing: message.body))
            return
        }
        let kind = dict["kind"] as? String ?? "?"

        if kind == "files" || kind == "dir" {
            let count = dict["count"] as? Int ?? 0
            logs.append("\(kind == "files" ? "选文件" : "选文件夹")：收到 \(count) 个")
            if let files = dict["files"] as? [[String: Any]] {
                for f in files.prefix(8) {
                    let name = f["name"] as? String ?? ""
                    let size = f["size"] as? Int ?? 0
                    let rel = f["rel"] as? String ?? ""
                    logs.append("· \(name) [\(size)] \(rel)")
                }
                if files.count > 8 {
                    logs.append("… 还有 \(files.count - 8) 个")
                }
            }
        } else if kind == "read" {
            let ok = dict["ok"] as? Bool ?? false
            if ok {
                let size = dict["size"] as? Int ?? 0
                let head = dict["head"] as? String ?? ""
                logs.append("读取内容：成功 ✓ size=\(size) head=\(String(head.prefix(24)))…")
            } else {
                let err = dict["error"] as? String ?? ""
                logs.append("读取内容：失败 ✗ \(err)")
            }
        } else {
            logs.append("收到：\(dict)")
        }
    }
}

struct WebImportTestView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var bridge = WebBridge()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WebTestWebView(bridge: bridge)

                VStack(alignment: .leading, spacing: 4) {
                    Text("App 收到的回传：")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 8)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            if bridge.logs.isEmpty {
                                Text("等待操作…")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.4))
                            } else {
                                ForEach(Array(bridge.logs.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(12)
                    }
                }
                .frame(height: 190)
                .background(Color.white.opacity(0.06))
            }
            .background(Color.black)
            .navigationTitle("导入实验")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct WebTestWebView: UIViewRepresentable {
    let bridge: WebBridge

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(bridge, name: "test")
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
  body { background:#000; color:#fff; font-family:-apple-system; padding:18px; margin:0; }
  h1 { font-size:22px; margin:6px 0 2px; }
  p.sub { color:#888; font-size:13px; margin:0 0 18px; }
  button { display:block; width:100%; padding:15px; margin:10px 0; border-radius:14px;
           background:#fff; color:#000; font-size:16px; font-weight:600; border:none; }
  button.alt { background:#2a2a2e; color:#fff; }
  input[type=file] { display:none; }
  #out { font-size:13px; line-height:1.7; color:#b9b9bd; white-space:pre-wrap; margin-top:16px;
         background:#111; border-radius:12px; padding:12px; }
</style>
</head>
<body>
<h1>导入实验</h1>
<p class="sub">点下面按钮，看能不能选中 U 盘里的文件 / 文件夹</p>

<button id="pickFiles">① 选择文件（可多选）</button>
<button class="alt" id="pickDir">② 选择文件夹</button>

<input type="file" id="fileInput" multiple>
<input type="file" id="dirInput" webkitdirectory>

<div id="out">等待操作…</div>

<script>
function send(obj) {
  try { window.webkit.messageHandlers.test.postMessage(obj); } catch (e) {}
}
function show(s) { document.getElementById('out').textContent = s; }

document.getElementById('pickFiles').addEventListener('click', function () {
  document.getElementById('fileInput').click();
});
document.getElementById('pickDir').addEventListener('click', function () {
  document.getElementById('dirInput').click();
});

document.getElementById('fileInput').addEventListener('change', async function (e) {
  var files = Array.prototype.slice.call(e.target.files || []);
  var txt = '① 选了 ' + files.length + ' 个文件\n';
  files.forEach(function (f) { txt += '· ' + f.name + '  (' + f.size + ' 字节)\n'; });
  show(txt);
  send({
    kind: 'files',
    count: files.length,
    files: files.map(function (f) { return { name: f.name, size: f.size, type: f.type, rel: f.webkitRelativePath || '' }; })
  });

  if (files.length > 0) {
    try {
      var f0 = files[0];
      var buf = await f0.slice(0, 512).arrayBuffer();
      var bytes = new Uint8Array(buf);
      var bin = '';
      for (var i = 0; i < bytes.length; i++) { bin += String.fromCharCode(bytes[i]); }
      send({ kind: 'read', ok: true, size: f0.size, head: btoa(bin) });
    } catch (err) {
      send({ kind: 'read', ok: false, error: String(err) });
    }
  }
});

document.getElementById('dirInput').addEventListener('change', function (e) {
  var files = Array.prototype.slice.call(e.target.files || []);
  var txt = '② 文件夹：' + files.length + ' 个文件\n';
  files.slice(0, 40).forEach(function (f) { txt += '· ' + f.name + '  [' + (f.webkitRelativePath || '') + ']\n'; });
  if (files.length > 40) { txt += '…\n'; }
  show(txt);
  send({
    kind: 'dir',
    count: files.length,
    files: files.map(function (f) { return { name: f.name, size: f.size, rel: f.webkitRelativePath || '' }; })
  });
});
</script>
</body>
</html>
"""#
}
