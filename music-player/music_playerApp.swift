//
//  music_playerApp.swift
//  music-player
//

import SwiftUI

@main
struct MusicPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
