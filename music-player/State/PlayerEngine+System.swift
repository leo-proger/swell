//
//  PlayerEngine+System.swift
//  music-player
//

import AppKit
import AVFoundation

/// Системный «шов» движка: мост к `NowPlayingCenter` (виджет «Сейчас играет» и
/// медиаклавиши) и делегат окончания трека. Вынесено из `PlayerEngine`, чтобы
/// платформенная специфика жила отдельно от логики очереди и воспроизведения.
extension PlayerEngine {
    /// Замыкания, через которые системные команды возвращаются в движок.
    func makeNowPlayingHandlers() -> NowPlayingCenter.Handlers {
        NowPlayingCenter.Handlers(
            play: { [weak self] in self?.systemPlay() },
            pause: { [weak self] in self?.systemPause() },
            toggle: { [weak self] in self?.togglePlayPause() },
            next: { [weak self] in self?.next() },
            previous: { [weak self] in self?.previous() },
            seek: { [weak self] in self?.seek(to: $0) }
        )
    }

    /// Команда «play» из системы (медиаклавиша / Пункт управления): возобновить.
    func systemPlay() {
        guard !isPlaying else { return }
        togglePlayPause()
    }

    /// Команда «pause» из системы: поставить на паузу, если играет.
    func systemPause() {
        guard isPlaying else { return }
        togglePlayPause()
    }

    /// Публикует текущее состояние в систему: виджет «Сейчас играет» + медиаклавиши.
    func publishNowPlaying() {
        if let track = currentTrack {
            nowPlaying.update(track: track, isPlaying: isPlaying, progress: progress)
        } else {
            nowPlaying.clear()
        }
    }

    /// Публикует обложку текущего трека. Зовётся из `RootView` после загрузки арта.
    func publishArtwork(_ image: NSImage?) {
        nowPlaying.updateArtwork(image)
    }
}

/// Делегат `AVAudioPlayer` для уведомления об окончании трека. Отдельный объект,
/// потому что `PlayerEngine` — не `NSObject`.
final class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: @MainActor () -> Void

    init(onFinish: @escaping @MainActor () -> Void) {
        self.onFinish = onFinish
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in onFinish() }
    }
}
