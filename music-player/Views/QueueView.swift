//
//  QueueView.swift
//  music-player
//

import AppKit
import SwiftUI

/// Очередь воспроизведения в стиле Apple Music iOS 18:
/// • History        — реально игравшие треки (сверху, затемнены), тап → обратный ход
/// • Now Playing    — текущий трек, выделен акцентом
/// • Playing Next   — ручная очередь (Play Next / Add to Queue), со своим Clear
/// • Continue Playing — контекстный хвост медиатеки
///
/// Обе зоны Up Next переупорядочиваются независимо; тап по любому треку = «играть его
/// и всё после» (промежуточные уходят в историю). Все строки отбиты от краёв единым
/// горизонтальным `contentMargins`, поэтому акцентная рамка текущего лежит внутри панели.
struct QueueView: View {
    let currentCover: NSImage?
    /// Видна ли сейчас очередь — по переходу в `true` прокручиваем к текущему треку.
    let isActive: Bool

    @Environment(PlayerEngine.self) private var engine

    var body: some View {
        let history = engine.history
        let userQueue = engine.userQueue
        let sourceTail = engine.sourceTail

        ScrollViewReader { proxy in
            List {
                if !history.isEmpty {
                    historySection(history)
                }

                if let track = engine.currentTrack {
                    nowPlayingSection(track)
                }

                if !userQueue.isEmpty {
                    playingNextSection(userQueue)
                }

                continuePlayingSection(sourceTail, hasManualQueue: !userQueue.isEmpty)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 52)
            .contentMargins(.horizontal, Theme.Spacing.m, for: .scrollContent)
            .contentMargins(.bottom, Theme.Spacing.m, for: .scrollContent)
            // Мягкий край Tahoe: контент (и закреплённый заголовок) плавно растворяется
            // у верхней кромки вместо резкого исчезновения при скролле.
            .scrollEdgeEffectStyle(.soft, for: .top)
            // Держим текущий трек на месте при любых сдвигах списка: открытие очереди,
            // смена трека и изменение истории (рост при advance / обрезание при Clear) —
            // всё, что меняет контент ВЫШЕ текущего и потому смещает его на экране.
            .onChange(of: isActive, initial: true) { _, active in
                if active { scrollToCurrent(proxy) }
            }
            .onChange(of: engine.currentTrackID) { _, _ in
                if isActive { scrollToCurrent(proxy) }
            }
            .onChange(of: engine.history.count) { _, _ in
                if isActive { scrollToCurrent(proxy) }
            }
        }
    }

    /// Прокручивает список так, чтобы текущий трек оказался сверху (история — выше, вне
    /// экрана). Небольшая задержка — дать List построить строки перед скроллом.
    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        guard let id = engine.currentTrackID else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(id, anchor: .top)
            }
        }
    }

    // MARK: - Секции

    private func historySection(_ history: [Track]) -> some View {
        Section {
            ForEach(history) { track in
                QueueRow(track: track, style: .history)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(rowInsets)
                    .contentShape(Rectangle())
                    .onTapGesture { engine.jumpTo(track) }
                    .moveDisabled(true)
            }
        } header: {
            HStack {
                sectionLabel("History", icon: "clock")
                Spacer()
                GlassActionButton(systemImage: "xmark", title: "Clear", shape: .capsule) {
                    engine.clearHistory()
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func nowPlayingSection(_ track: Track) -> some View {
        Section {
            QueueNowPlayingRow(track: track, cover: currentCover)
                .padding(.horizontal, Theme.Spacing.s)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: Theme.Radius.artwork, style: .continuous)
                        .fill(Theme.accent.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.artwork, style: .continuous)
                                .strokeBorder(Theme.accent.opacity(0.55), lineWidth: 1)
                        )
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .moveDisabled(true)
                .id(track.id)
        }
    }

    /// Ручная очередь: со своим Clear (чистит только её) и независимым reorder.
    private func playingNextSection(_ tracks: [Track]) -> some View {
        Section {
            ForEach(tracks) { track in
                queueRow(track)
            }
            .onMove { engine.moveUserQueue(fromOffsets: $0, toOffset: $1) }
        } header: {
            HStack {
                sectionLabel("Playing Next", icon: "text.line.first.and.arrowtriangle.forward")
                Spacer()
                GlassActionButton(systemImage: "xmark", title: "Clear", shape: .capsule) {
                    engine.clearQueue()
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// Контекстный хвост медиатеки. Пустую заглушку показываем только когда пусто всё
    /// будущее (ни ручной очереди, ни хвоста).
    private func continuePlayingSection(_ tracks: [Track], hasManualQueue: Bool) -> some View {
        Section {
            if tracks.isEmpty {
                if !hasManualQueue {
                    Text("No upcoming tracks")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, Theme.Spacing.l)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .moveDisabled(true)
                }
            } else {
                ForEach(tracks) { track in
                    queueRow(track)
                }
                .onMove { engine.moveSourceTail(fromOffsets: $0, toOffset: $1) }
            }
        } header: {
            sectionLabel("Continue Playing", icon: "music.note.list")
                .padding(.vertical, 4)
        }
    }

    /// Строка предстоящего трека (общая для обеих зон Up Next): тап → играть отсюда,
    /// контекстное меню → убрать из очереди.
    private func queueRow(_ track: Track) -> some View {
        QueueRow(track: track, style: .upNext)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(rowInsets)
            .contentShape(Rectangle())
            .onTapGesture { engine.jumpTo(track) }
            .contextMenu {
                Button(role: .destructive) {
                    engine.removeFromQueue(track)
                } label: {
                    Label("Remove from queue", systemImage: "minus.circle")
                }
            }
    }

    // MARK: - Вспомогательное

    /// Вертикальные отступы строки; горизонтальное выравнивание задаёт `contentMargins`.
    private var rowInsets: EdgeInsets {
        EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0)
    }

    /// Заголовок секции на матовой стеклянной «пилюле» — текст читается, когда под
    /// закреплённым заголовком проезжает контент.
    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, 5)
            .glassEffect(.regular, in: .capsule)
    }
}
