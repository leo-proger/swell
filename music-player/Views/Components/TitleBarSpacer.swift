//
//  TitleBarSpacer.swift
//  music-player
//

import SwiftUI

/// Прозрачный отступ под зоной тайтлбара/«светофора» окна. Единый источник высоты
/// (`Theme.Layout.titleBarInset`), чтобы обе колонки начинались на одном уровне.
struct TitleBarSpacer: View {
    var body: some View {
        Color.clear.frame(height: Theme.Layout.titleBarInset)
    }
}
