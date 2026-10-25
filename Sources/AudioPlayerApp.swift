import SwiftUI
import AVFoundation

@main
struct AudioPlayerApp: App {
    @StateObject private var player = PlayerModel()
    @StateObject private var library = LibraryModel()

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
