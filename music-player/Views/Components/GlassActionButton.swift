//
//  GlassActionButton.swift
//  music-player
//

import SwiftUI

/// Утилитарная кнопка в стиле macOS Tahoe: тонированное «акцентное стекло»
/// (Liquid Glass с лёгким оттенком акцента), а не плотная заливка. Единый стиль
/// для второстепенных действий — обновить, сменить папку, перемешать, очистить.
///
/// Две формы: круглая (только иконка) и капсула (иконка + подпись). Стандартные
/// модификаторы `.disabled(_:)` и `.help(_:)` навешиваются снаружи как на любую вью.
struct GlassActionButton: View {
    enum Shape { case circle, capsule }

    let systemImage: String
    var title: String?
    var shape: Shape = .circle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            content
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(minWidth: shape == .circle ? 30 : nil, minHeight: 30)
                .padding(.horizontal, shape == .capsule ? Theme.Spacing.m : 0)
                .glassEffect(
                    .regular.tint(Theme.accent.opacity(0.16)).interactive(),
                    in: glassShape
                )
                .contentShape(shape == .circle ? AnyShape(Circle()) : AnyShape(Capsule()))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if let title {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
        } else {
            Image(systemName: systemImage)
        }
    }

    private var glassShape: AnyShape {
        shape == .circle ? AnyShape(Circle()) : AnyShape(Capsule())
    }
}
