//
//  RootView.swift
//  music-player
//

import AppKit
import SwiftUI

/// Корневая раскладка Swell: две колонки во всю высоту, разделённые перетаскиваемой
/// границей. Слева — поиск и список треков, справа — управление медиатекой и
/// «сейчас играет». Пока папка не выбрана, показывается стартовый экран. Фон —
/// прозрачный блюр с амбиентным свечением под цвет обложки текущего трека.
struct RootView: View {
    @State private var library = LibraryStore()
    @State private var engine = PlayerEngine()
    @State private var artworkProvider = ArtworkProvider()

    /// Ширина левой панели — меняется перетаскиванием границы.
    @State private var listWidth: CGFloat = Theme.Layout.listDefaultWidth
    /// Обложка текущего трека (полный размер) для правой панели.
    @State private var currentCover: NSImage?
    /// Цвета амбиентного фона, подобранные под обложку.
    @State private var ambientColors: [Color] = [.accentColor]

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()

            AmbientBackdrop(colors: ambientColors)
                .ignoresSafeArea()

            content

            // Делитель на уровне root ZStack — игнорирует safe area и идёт от
            // самого верха окна (включая зону тайтлбара) до самого низа.
            if library.folderName != nil {
                PanelDivider(width: $listWidth, range: Theme.Layout.listWidthRange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, listWidth - 1)
                    .ignoresSafeArea()
            }
        }
        .environment(library)
        .environment(engine)
        .environment(artworkProvider)
        .background(WindowConfigurator())
        .frame(minWidth: Theme.Layout.windowMinWidth, minHeight: Theme.Layout.windowMinHeight)
        .tint(Theme.accent)
        .task { await restoreOnLaunch() }
        .task(id: engine.currentTrackID) { await refreshNowPlaying() }
        .onChange(of: library.tracks) { _, tracks in
            engine.setLibrary(tracks)
        }
    }

    @ViewBuilder
    private var content: some View {
        if library.folderName == nil {
            WelcomeView()
        } else {
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    TitleBarSpacer()
                    TrackListView()
                }
                .frame(width: listWidth)
                .frame(maxHeight: .infinity)
                .background(.ultraThinMaterial)

                VStack(spacing: 0) {
                    TitleBarSpacer()
                    TopToolbar()
                    NowPlayingView(cover: currentCover)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
    }

    /// Восстанавливает медиатеку (из кэша — мгновенно) и состояние воспроизведения.
    private func restoreOnLaunch() async {
        await library.restore()
        engine.setLibrary(library.tracks)
        if let saved = PlaybackPersistence.load() {
            engine.restore(saved, tracks: library.tracks)
        }
    }

    /// Грузит обложку текущего трека, подбирает под неё цвет амбиентного фона и
    /// публикует её в системный виджет «Сейчас играет».
    private func refreshNowPlaying() async {
        currentCover = nil
        engine.publishArtwork(nil)
        guard let track = engine.currentTrack else {
            ambientColors = [.accentColor]
            return
        }

        if let data = await ArtworkLoader.load(url: track.url) {
            currentCover = NSImage(data: data)
            ambientColors = ColorExtractor.ambientColors(from: data) ?? track.artworkColors
            engine.publishArtwork(currentCover)
        } else {
            ambientColors = track.artworkColors
        }
    }
}
