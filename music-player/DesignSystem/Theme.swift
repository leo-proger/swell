//
//  Theme.swift
//  music-player
//

import AppKit
import SwiftUI

/// Единые дизайн-токены плеера.
///
/// Современный «живой» стиль: прозрачный фон с блюром, амбиентное свечение от
/// цвета текущего трека и системный акцент на управлении.
enum Theme {
    /// Акцент интерфейса — системный цвет акцента macOS.
    /// Используется только как подчёркивание (границы, иконки, заливка дорожек),
    /// но не как фон.
    static let accent = Color.accentColor

    /// Нейтральный серый разделитель между панелями — нативный `separatorColor`.
    static let separator = Color(nsColor: .separatorColor)

    /// Цвета действий при свайпе по треку.
    enum Swipe {
        static let queueEnd = Color(red: 0.941, green: 0.592, blue: 0.282) // #F09748
        static let playNext = Color(red: 0.439, green: 0.482, blue: 0.965) // #707BF6
        static let delete = Color(red: 0.922, green: 0.325, blue: 0.302) // #EB534D
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 20
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let control: CGFloat = 12
        static let panel: CGFloat = 20
        static let artwork: CGFloat = 16
    }

    /// Константы раскладки окна и панелей — чтобы не было «магических» чисел во вью.
    enum Layout {
        /// Резерв сверху под зону тайтлбара и «светофор» окна.
        static let titleBarInset: CGFloat = 30
        /// Минимальный размер окна.
        static let windowMinWidth: CGFloat = 940
        static let windowMinHeight: CGFloat = 720
        /// Стартовая ширина левой панели и допустимый диапазон при перетаскивании.
        static let listDefaultWidth: CGFloat = 360
        static let listWidthRange: ClosedRange<CGFloat> = 300 ... 560
    }
}
