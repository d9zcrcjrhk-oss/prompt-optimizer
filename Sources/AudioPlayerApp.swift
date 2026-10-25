import SwiftUI
import AVFoundation
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        LibraryModel.shared.receiveFile(url)
        return true
    }
}

@main
struct AudioPlayerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var player = PlayerModel()
    @StateObject private var library = LibraryModel.shared

    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(player)
                .environmentObject(library)
                .onOpenURL { url in
                    library.receiveFile(url)
                }
        }
    }
}
