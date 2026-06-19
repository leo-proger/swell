//
//  NowPlayingCenter.swift
//  music-player
//

import AppKit
import MediaPlayer

/// Тонкий шов над системными MediaPlayer-API: виджет «Сейчас играет» (Пункт
/// управления / строка меню) и медиаклавиши (play/pause, next/prev, перемотка).
///
/// Платформенная специфика изолирована здесь — движок только дергает методы.
/// На macOS `AVAudioSession` не нужен: достаточно зарегистрировать remote-команды
/// и заполнить `nowPlayingInfo`, чтобы приложение стало активным «Сейчас играет».
@MainActor
final class NowPlayingCenter {
    /// Команды из системы перенаправляются в эти замыкания (к `PlayerEngine`).
    struct Handlers {
        let play: @MainActor () -> Void
        let pause: @MainActor () -> Void
        let toggle: @MainActor () -> Void
        let next: @MainActor () -> Void
        let previous: @MainActor () -> Void
        let seek: @MainActor (TimeInterval) -> Void
    }

    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()
    private let handlers: Handlers

    init(handlers: Handlers) {
        self.handlers = handlers
        configureCommands()
    }

    // MARK: - Регистрация команд

    private func configureCommands() {
        let center = commandCenter

        center.playCommand.addTarget { [handlers] _ in
            Task { @MainActor in handlers.play() }
            return .success
        }
        center.pauseCommand.addTarget { [handlers] _ in
            Task { @MainActor in handlers.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [handlers] _ in
            Task { @MainActor in handlers.toggle() }
            return .success
        }
        center.nextTrackCommand.addTarget { [handlers] _ in
            Task { @MainActor in handlers.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [handlers] _ in
            Task { @MainActor in handlers.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [handlers] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let time = event.positionTime
            Task { @MainActor in handlers.seek(time) }
            return .success
        }

        for command in [
            center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
            center.nextTrackCommand, center.previousTrackCommand,
            center.changePlaybackPositionCommand
        ] {
            command.isEnabled = true
        }
        // Жесты перемотки/пропуска не используем — выключаем, чтобы не плодить кнопки.
        for command in [
            center.seekForwardCommand, center.seekBackwardCommand,
            center.skipForwardCommand, center.skipBackwardCommand
        ] {
            command.isEnabled = false
        }
    }

    // MARK: - Публикация состояния

    /// Обновляет метаданные и состояние воспроизведения. Систему достаточно
    /// уведомлять на событиях и ~раз в секунду — позицию она интерполирует по rate.
    func update(track: Track, isPlaying: Bool, progress: TimeInterval) {
        var info = infoCenter.nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = track.title
        info[MPMediaItemPropertyArtist] = track.artist
        info[MPMediaItemPropertyAlbumTitle] = track.album
        info[MPMediaItemPropertyPlaybackDuration] = track.duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = isPlaying ? .playing : .paused
    }

    /// Обновляет обложку отдельно — она грузится асинхронно уже после метаданных.
    func updateArtwork(_ image: NSImage?) {
        var info = infoCenter.nowPlayingInfo ?? [:]
        if let image {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
                image
            }
        } else {
            info[MPMediaItemPropertyArtwork] = nil
        }
        infoCenter.nowPlayingInfo = info
    }

    /// Сбрасывает «Сейчас играет», когда ничего не воспроизводится.
    func clear() {
        infoCenter.nowPlayingInfo = nil
        infoCenter.playbackState = .stopped
    }
}
