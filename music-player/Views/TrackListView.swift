//
//  TrackListView.swift
//  music-player
//

import AppKit
import SwiftUI

/// Левая зона — поиск, прогресс загрузки и список треков (нативный `List` ради
/// аккуратного скролла, свайпов и контекстного меню).
struct TrackListView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(PlayerEngine.self) private var engine

    @State private var hoveredID: Track.ID?
    @State private var infoTrack: Track?
    @State private var deleteCandidate: Track?
    /// Трек, ожидающий выбора Clear / Keep: тап «играть сейчас» при непустой ручной очереди.
    @State private var playNowCandidate: Track?

    var body: some View {
        @Bindable var library = library
        let tracks = library.filteredTracks

        VStack(spacing: 0) {
            searchField(text: $library.searchQuery)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.top, Theme.Spacing.m)

            header(count: tracks.count)

            if case let .loading(done, total) = library.state {
                scanProgress(done: done, total: total)
            }

            content(tracks)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $infoTrack) { track in
            TrackInfoView(track: track)
        }
        .alert("Move to Trash?", isPresented: deleteAlertBinding, presenting: deleteCandidate) { track in
            Button("Move to Trash", role: .destructive) { library.deleteFile(track) }
            Button("Cancel", role: .cancel) {}
        } message: { track in
            Text("“\(track.title)” will be moved to the system Trash.")
        }
        // Тап «играть сейчас» при непустой ручной очереди: спрашиваем, сохранить её или
        // начать с чистого листа (опция Clear, которую показывает и Apple Music).
        .confirmationDialog(
            "Queue has manually added tracks",
            isPresented: playNowAlertBinding,
            presenting: playNowCandidate
        ) { track in
            Button("Clear queue & play") { engine.playNow(track, keepUserQueue: false) }
            Button("Keep queue") { engine.playNow(track, keepUserQueue: true) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Keep your Play Next / Add to Queue tracks, or clear them and start fresh?")
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deleteCandidate != nil },
            set: { if !$0 { deleteCandidate = nil } }
        )
    }

    private var playNowAlertBinding: Binding<Bool> {
        Binding(
            get: { playNowCandidate != nil },
            set: { if !$0 { playNowCandidate = nil } }
        )
    }

    /// Тап по треку медиатеки: повторный тап по текущему — перезапуск; при непустой
    /// ручной очереди — спросить Clear/Keep; иначе просто играть.
    private func handleTap(_ track: Track) {
        if track.id == engine.currentTrackID || !engine.hasUserQueue {
            engine.playNow(track)
        } else {
            playNowCandidate = track
        }
    }

    // MARK: - Контент

    @ViewBuilder
    private func content(_ tracks: [Track]) -> some View {
        if tracks.isEmpty {
            if library.searchQuery.isEmpty, library.state == .loaded {
                ContentUnavailableView(
                    "No audio files",
                    systemImage: "music.note.list",
                    description: Text("No supported tracks were found in this folder")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !library.searchQuery.isEmpty {
                ContentUnavailableView.search
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
            }
        } else {
            trackList(tracks)
        }
    }

    // MARK: - Список

    private func trackList(_ tracks: [Track]) -> some View {
        List {
            ForEach(tracks) { track in
                row(for: track)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 56)
        // Горизонтальный отступ задаём через contentMargins, а не per-row insets — тогда
        // подсветка контекст-меню совпадает со скруглённым фоном строки (не «съезжает»).
        .contentMargins(.horizontal, Theme.Spacing.s, for: .scrollContent)
    }

    private func row(for track: Track) -> some View {
        TrackRow(
            track: track,
            isCurrent: track.id == engine.currentTrackID,
            isPlaying: engine.isPlaying && track.id == engine.currentTrackID,
            isHovered: hoveredID == track.id
        )
        // Фон строки задаём через listRowBackground (а не .background внутри строки):
        // он заполняет ровно ту ячейку, которую подсвечивает система при right-click,
        // поэтому рамка контекст-меню совпадает с фоном, а не «съезжает» по всему item.
        .listRowBackground(rowBackground(
            isCurrent: track.id == engine.currentTrackID,
            isHovered: hoveredID == track.id
        ))
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
        .contentShape(Rectangle())
        .onTapGesture { handleTap(track) }
        .onHover { hoveredID = $0 ? track.id : nil }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { engine.enqueueNext(track) } label: {
                Label("Play next", systemImage: "text.insert")
            }
            .tint(Theme.Swipe.playNext)
            Button { engine.enqueueLast(track) } label: {
                Label("To end", systemImage: "text.append")
            }
            .tint(Theme.Swipe.queueEnd)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { deleteCandidate = track } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(Theme.Swipe.delete)
        }
        .contextMenu {
            Button { infoTrack = track } label: {
                Label("Info", systemImage: "info.circle")
            }
            Button { engine.enqueueNext(track) } label: {
                Label("Play next", systemImage: "text.insert")
            }
            Button { engine.enqueueLast(track) } label: {
                Label("Add to queue", systemImage: "text.append")
            }
            Divider()
            Button(role: .destructive) { deleteCandidate = track } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    /// Фон строки (наведение/текущий трек). Без скругления — прямоугольник во всю
    /// ширину ячейки, чтобы он совпадал с прямоугольной системной подсветкой right-click.
    @ViewBuilder
    private func rowBackground(isCurrent: Bool, isHovered: Bool) -> some View {
        if isCurrent {
            Rectangle()
                .fill(Theme.accent.opacity(0.14))
                .overlay(Rectangle().strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1))
        } else if isHovered {
            Rectangle().fill(.white.opacity(0.07))
        } else {
            Color.clear
        }
    }

    // MARK: - Прогресс загрузки

    private func scanProgress(done: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ProgressView(value: total > 0 ? Double(done) / Double(total) : nil)
                .tint(Theme.accent)
            Text(total > 0 ? "Loading \(done) of \(total)" : "Finding files…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.s)
    }

    // MARK: - Поиск

    private func searchField(text: Binding<String>) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: text)
                .textFieldStyle(.plain)
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: - Шапка

    private func header(count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Tracks")
                .font(.system(.title3, weight: .bold))
            Text("\(count)")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            GlassActionButton(systemImage: "shuffle") {
                engine.playRandom()
            }
            .disabled(count == 0)
            .help("Shuffle all")
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.s)
    }
}

/// Строка трека. Лениво подгружает миниатюру обложки; на ховере показывает кнопку
/// play, активный трек выделяется акцентом и анимированным эквалайзером.
private struct TrackRow: View {
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool
    let isHovered: Bool

    @Environment(ArtworkProvider.self) private var artworkProvider
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            artwork

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(isCurrent ? Theme.accent : .primary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(track.duration.timecode).monoTimecode()
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .task(id: track.id) {
            // Дебаунс: при быстром скролле строка успеет исчезнуть, и тяжёлая
            // загрузка обложки даже не начнётся.
            try? await Task.sleep(for: .milliseconds(120))
            if Task.isCancelled { return }
            thumbnail = await artworkProvider.thumbnail(for: track.url)
        }
    }

    private var artwork: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return shape
            .fill(track.artworkGradient)
            .frame(width: 44, height: 44)
            .overlay {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(shape)
                }
            }
            .overlay {
                if isCurrent {
                    shape.fill(.black.opacity(0.45))
                    EqualizerIndicator(isAnimating: isPlaying)
                } else if isHovered {
                    shape.fill(.black.opacity(0.35))
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
    }
}
