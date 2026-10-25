# 本地听书 · iOS 原生 App（骨架版）

> 这是**打通安装链路**的第一步版本：选文件夹、按文件名排序、播放、记住进度、后台/锁屏播放。
> 确认能装到手机后，再迭代「合集、定时关闭、按集排序、封面」等完整功能。

## 它和 PWA 的区别（为什么之前说 PWA 不行）

| | PWA（网页） | 这个原生 App |
|---|---|---|
| 20GB 音频 | 塞不进浏览器存储（约 1GB 上限） | 只记文件夹书签，**不复制**，直接读 |
| 下次打开 | 要重新复制/可能被清 | 书签还原，直接可读 |
| 锁屏/后台 | 受限 | AVAudioSession + 锁屏控制 |
| 安装 | 加到主屏幕 | 侧载（证书签名） |

## 关键实现

- `FolderPicker`：用系统文件选择器选**文件夹**（`asCopy: false`，不复制文件）。
- 选中后 `startAccessingSecurityScopedResource()`，并保存 **security-scoped bookmark** 到 UserDefaults。
- 下次启动 `restoreFolder()` 用书签还原路径 —— 这就是「记住文件路径，下次直接读」。
- 播放用 AVPlayer，进度按 `pos-<文件名>` 存 UserDefaults；锁屏用 MPNowPlayingInfoCenter + MPRemoteCommandCenter。

## 构建（不碰 Mac，用 GitHub 云端编译）

1. 新建一个 GitHub 仓库（**Public 最省，Actions 免费用**）。
2. 把这个 `ios-app/` 目录**里面的全部内容**（`project.yml`、`Sources/`、`.github/`）作为仓库根目录推送上去。
3. 进仓库 → **Actions** → 左侧 `Build IPA` → `Run workflow`。
4. 跑完在 **Artifacts** 里下载 `AudiobookPlayer-ipa.zip`，解压得到 `AudiobookPlayer.ipa`（未签名）。

> 第一次构建大概率能过；若报错，把 Actions 的红色日志发我，我按报错改代码。

## 签名安装（用你买的证书）

证书通常买到 **.p12 + 描述文件(.mobileprovision)** 或卖家直接给「代签服务」。两种做法：

**A. 在 iPhone 上签（轻松签 / QSign，最省事）**
1. iPhone 装「轻松签」（App Store 或官网）。
2. 导入证书（p12 + 描述文件），导入 `AudiobookPlayer.ipa`。
3. 选证书 → 签名 → 安装。

**B. 在 Windows 上签（Sideloadly）**
1. 电脑装 Sideloadly，连上 iPhone。
2. 载入 `AudiobookPlayer.ipa` + 你的证书，点 Start。

**C. 让淘宝卖家代签名**
把 `AudiobookPlayer.ipa` 发给卖家，让他用证书签好再发回给你装。

## 买证书的注意事项（避免踩坑）

- **个人开发者证书**：稳定、有效期长（约 1 年），但**要绑定你手机的 UDID**，卖家一般会教你怎么提 UDID。
- **企业证书**：不用绑 UDID、装完周期长，但**容易突然被苹果吊销**（一夜之间全掉签），适合临时用。
- **共享证书**：便宜，但随时可能被他人连累掉签。
- 结论：想长期稳定 → **个人证书**；只想快装快试 → 企业/共享证书。
- 买前问一句：**「包不包签名工具/教程？支不支持 iOS 17/18？」**

## 已知限制（骨架版）

- 只支持**一个文件夹**、平铺列表（还没有合集/多文件夹）。
- 进度用文件名当 key（不同文件夹同名会冲突），后续换成书签+文件 ID。
- 暂未做定时关闭、倍速切换、封面。
- 我这边没有 macOS，**无法本地编译验证**，所以需要靠 GitHub Actions 的日志迭代修错——这是正常的，不是你的问题。
