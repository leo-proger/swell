//
//  QueueToggleButton.swift
//  music-player
//

import SwiftUI

/// Кнопка переключения «полный плеер ⇄ очередь». Liquid Glass круг; в активном
/// состоянии (очередь открыта) — акцентная иконка и акцентная обводка.
struct QueueToggleButton: View {
    @Binding var showQueue: Bool

    var body: some View {
        Button {
            withAnimation(.smooth(duration: 0.38)) {
                showQueue.toggle()
            }
        } label: {
            Image(systemName: "list.bullet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(showQueue ? Theme.accent : .primary)
                .frame(width: 46, height: 46)
                .glassEffect(.regular, in: .circle)
                .overlay {
                    if showQueue {
                        Circle().strokeBorder(Theme.accent.opacity(0.7), lineWidth: 1.5)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(showQueue ? "Hide queue" : "Show queue")
    }
}
