//
//  PanelDivider.swift
//  music-player
//

import AppKit
import SwiftUI

/// Перетаскиваемая граница между панелями во всю высоту окна. Базовая серая линия
/// видна всегда; при наведении поверх неё плавно проявляется акцентная подсветка
/// (чуть толще). Курсор — стрелки изменения размера.
///
/// Ширина в лейауте постоянна (2pt), толщина акцента рисуется overlay-ем, поэтому
/// перетаскивание не «дрожит». Зона захвата — прозрачный overlay шире линии; драг
/// считается в глобальных координатах.
struct PanelDivider: View {
    @Binding var width: CGFloat
    let range: ClosedRange<CGFloat>

    @State private var hovering = false
    @State private var dragStartWidth: CGFloat?

    var body: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(width: 2)
            .frame(maxHeight: .infinity)
            .overlay {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: hovering ? 3 : 2)
                    .opacity(hovering ? 1 : 0)
                    .shadow(color: Theme.accent.opacity(hovering ? 0.6 : 0), radius: 6)
                    .animation(.easeInOut(duration: 0.2), value: hovering)
            }
            .overlay {
                Color.clear
                    .frame(width: 14)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        hovering = inside
                        if inside {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture(coordinateSpace: .global)
                            .onChanged { value in
                                let base = dragStartWidth ?? width
                                dragStartWidth = base
                                let proposed = base + value.translation.width
                                width = min(max(proposed, range.lowerBound), range.upperBound)
                            }
                            .onEnded { _ in dragStartWidth = nil }
                    )
            }
    }
}
