import SwiftUI
import AVFoundation

@main
struct AudioPlayerApp: App {
    @StateObject private var player = PlayerModel()

    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(player)
        }
    }
}
