//
//  VisualEffectBackground.swift
//  music-player
//

import AppKit
import SwiftUI

/// Прозрачный фон с блюром рабочего стола.
///
/// `NSVisualEffectView` в режиме `.behindWindow` размывает содержимое за окном —
/// это и даёт «прозрачный фон с блюром». Поверх него ложатся Liquid Glass
/// компоненты управления.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Делает окно по-настоящему прозрачным, чтобы сработал `.behindWindow` блюр,
/// и убирает титлбар ради цельной стеклянной поверхности.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
