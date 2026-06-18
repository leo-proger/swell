//
//  PlayerEngine.swift
//  music-player
//

import AVFoundation
import Observation

/// Воспроизведение и навигация по очереди. Играет реальные файлы через `AVAudioPlayer`.
///
/// Вся логика очереди живёт в чистом `PlayQueue` (три региона: история / текущий /
/// Up Next = ручная очередь + хвост контекста). Движок отвечает за звук, таймер
/// прогресса, системную интеграцию и персист. Состояние переживает краши и рестарты.
/// Загрузка файла идёт с подкачкой в фоне, чтобы переключение треков не лагало.
@MainActor
@Observable
final class PlayerEngine {
    enum RepeatMode: String {
        case off, all, one
    }

    private(set) var model = PlayQueue()

    private(set) var isPlaying = false
    /// Текущая позиция воспроизведения в секундах.
    private(set) var progress: TimeInterval = 0
    var repeatMode: RepeatMode = .off {
        didSet { if repeatMode != oldValue { persist() } }
    }

    /// Шаффл — режим формирования контекстного хвоста; ручную очередь не трогает.
    var isShuffle: Bool {
        get { model.shuffle }
        set {
            model.setShuffle(newValue)
            persist()
        }
    }

    var volume: Double = 0.7 {
        didSet { player?.volume = Float(volume) }
    }

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var playerData: Data?
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private var lastPersist = Date.distantPast
    @ObservationIgnored private lazy var playbackDelegate = PlaybackDelegate { [weak self] in
        self?.handlePlaybackFinished()
    }

    /// Системная интеграция (см. `PlayerEngine+System`): «Сейчас играет» + медиаклавиши.
    @ObservationIgnored lazy var nowPlaying = NowPlayingCenter(handlers: makeNowPlayingHandlers())

    // MARK: - Медиатека

    /// Обновляет контекст из медиатеки (старт, рескан, удаление трека). Перезагружает
    /// аудио только если текущий трек исчез и заменён следующим.
    func setLibrary(_ tracks: [Track]) {
        switch model.setSource(tracks) {
        case .unchanged, .preselected:
            break
        case .currentReplaced:
            if let track = model.current {
                progress = 0
                Task { await loadAndPlay(track, autoplay: isPlaying, seekTo: 0) }
            } else {
                stop()
            }
        }
        persist()
    }

    // MARK: - Запуск воспроизведения

    /// «Играть сейчас» по тапу в медиатеке. `keepUserQueue` — судьба ручной очереди
    /// (вью спрашивает у пользователя, когда она не пуста).
    func playNow(_ track: Track, keepUserQueue: Bool = true) {
        guard track.id != model.current?.id else {
            restartCurrent()
            return
        }
        model.playNow(track, keepUserQueue: keepUserQueue)
        loadCurrent(autoplay: true)
        persist()
    }

    /// Тап по треку в окне очереди (будущее или история) — см. `PlayQueue.jumpTo`.
    func jumpTo(_ track: Track) {
        guard track.id != model.current?.id else {
            restartCurrent()
            return
        }
        model.jumpTo(track)
        loadCurrent(autoplay: true)
        persist()
    }

    /// Случайный трек по текущему режиму шаффла (кнопка-шаффл в шапке списка).
    func playRandom() {
        model.playRandom()
        loadCurrent(autoplay: true)
        persist()
    }

    // MARK: - Ручная очередь

    /// Play Next: в начало ручной очереди. Пустой плеер → запускает воспроизведение.
    func enqueueNext(_ track: Track) {
        guard model.current != nil else {
            playNow(track)
            return
        }
        model.playNext(track)
        persist()
    }

    /// Add to Queue: в конец ручной очереди (перед хвостом). Пустой плеер → запускает.
    func enqueueLast(_ track: Track) {
        guard model.current != nil else {
            playNow(track)
            return
        }
        model.addToQueue(track)
        persist()
    }

    func removeFromQueue(_ track: Track) {
        model.removeFromQueue(track)
        persist()
    }

    /// Чистит ручную очередь (кнопка Clear на секции «Playing Next»).
    func clearQueue() {
        model.clearUserQueue()
        persist()
    }

    func clearHistory() {
        model.clearHistory()
        persist()
    }

    func moveUserQueue(fromOffsets source: IndexSet, toOffset destination: Int) {
        model.moveUserQueue(fromOffsets: source, toOffset: destination)
        persist()
    }

    func moveSourceTail(fromOffsets source: IndexSet, toOffset destination: Int) {
        model.moveSourceQueue(fromOffsets: source, toOffset: destination)
        persist()
    }

    // MARK: - Восстановление

    /// Восстанавливает очередь, текущий трек и позицию из сохранённого состояния.
    /// URL'ы сверяются с актуальной медиатекой — пропавшие записи отбрасываются.
    func restore(_ state: PlaybackState, tracks: [Track]) {
        repeatMode = RepeatMode(rawValue: state.repeatMode) ?? .off
        volume = state.volume

        let byURL = Dictionary(tracks.map { ($0.url, $0) }, uniquingKeysWith: { first, _ in first })
        model.restore(PlayQueue.Snapshot(
            history: state.history.compactMap { byURL[$0] },
            current: state.current.flatMap { byURL[$0] },
            userQueue: state.userQueue.compactMap { byURL[$0] },
            sourceQueue: state.sourceQueue.compactMap { byURL[$0] },
            source: tracks,
            shuffle: state.isShuffle
        ))

        guard let track = model.current else { return }
        progress = state.progress
        Task { await loadAndPlay(track, autoplay: false, seekTo: state.progress) }
    }

    // MARK: - Управление воспроизведением

    func togglePlayPause() {
        guard let track = model.current else { return }
        if let player {
            if isPlaying {
                player.pause()
                isPlaying = false
                stopTicker()
            } else {
                player.play()
                isPlaying = true
                startTicker()
            }
            persist()
        } else {
            isPlaying = true
            Task { await loadAndPlay(track, autoplay: true, seekTo: progress) }
        }
    }

    func next() {
        if model.advance() {
            loadCurrent(autoplay: isPlaying)
        } else if repeatMode == .all {
            model.restartContext()
            loadCurrent(autoplay: isPlaying)
        } else {
            // Конец очереди, повтор выключен — останавливаемся на месте.
            isPlaying = false
            player?.pause()
            stopTicker()
        }
        persist()
    }

    func previous() {
        // В пределах первых 3 секунд — к предыдущему треку, иначе к началу текущего.
        if progress > 3 {
            seek(to: 0)
            return
        }
        if model.goBack() {
            loadCurrent(autoplay: isPlaying)
            persist()
        } else {
            seek(to: 0)
        }
    }

    func seek(to time: TimeInterval) {
        guard let player else {
            progress = max(0, time)
            return
        }
        let clamped = min(max(time, 0), player.duration)
        player.currentTime = clamped
        progress = clamped
        persist()
    }

    // MARK: - Приватное

    /// Загружает текущий трек модели и (опционально) запускает воспроизведение.
    private func loadCurrent(autoplay: Bool) {
        guard let track = model.current else {
            stop()
            return
        }
        progress = 0
        Task { await loadAndPlay(track, autoplay: autoplay, seekTo: 0) }
    }

    /// Перезапускает текущий трек с начала (повторный тап по уже играющему).
    private func restartCurrent() {
        if let player {
            player.currentTime = 0
            progress = 0
            player.play()
            isPlaying = true
            startTicker()
            persist()
        } else if let track = model.current {
            isPlaying = true
            Task { await loadAndPlay(track, autoplay: true, seekTo: 0) }
        }
    }

    /// Грузит файл в фоне (через mmap) и создаёт плеер. Свежий запрос отменяет старый
    /// по `loadGeneration`, поэтому быстрые переключения не дерутся за плеер.
    private func loadAndPlay(_ track: Track, autoplay: Bool, seekTo: TimeInterval) async {
        loadGeneration += 1
        let generation = loadGeneration
        stopTicker()

        let url = track.url
        let data = await Task.detached(priority: .userInitiated) {
            try? Data(contentsOf: url, options: .mappedIfSafe)
        }.value

        guard generation == loadGeneration else { return }

        guard let data, let newPlayer = try? AVAudioPlayer(data: data) else {
            player = nil
            playerData = nil
            isPlaying = false
            return
        }

        newPlayer.delegate = playbackDelegate
        newPlayer.volume = Float(volume)
        newPlayer.prepareToPlay()
        if seekTo > 0 {
            newPlayer.currentTime = min(seekTo, newPlayer.duration)
        }
        player = newPlayer
        playerData = data
        progress = newPlayer.currentTime

        if autoplay {
            newPlayer.play()
            isPlaying = true
            startTicker()
        } else {
            isPlaying = false
        }
        persist()
    }

    private func stop() {
        player?.stop()
        player = nil
        playerData = nil
        isPlaying = false
        progress = 0
        stopTicker()
    }

    private func handlePlaybackFinished() {
        switch repeatMode {
        case .one:
            player?.currentTime = 0
            progress = 0
            player?.play()
            startTicker()
        case .all:
            if model.advance() {
                loadCurrent(autoplay: true)
            } else {
                model.restartContext()
                loadCurrent(autoplay: true)
            }
        case .off:
            if model.advance() {
                loadCurrent(autoplay: true)
            } else {
                isPlaying = false
                stopTicker()
                progress = model.current?.duration ?? 0
                persist()
            }
        }
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard let player, isPlaying else { return }
        progress = player.currentTime
        if Date.now.timeIntervalSince(lastPersist) >= 1 {
            persist()
        }
    }

    /// Сохраняет состояние воспроизведения (в фоне). Вызывается на событиях и раз в секунду.
    private func persist() {
        publishNowPlaying()
        lastPersist = Date.now
        let state = PlaybackState(
            history: model.history.map(\.url),
            userQueue: model.userQueue.map(\.url),
            sourceQueue: model.sourceQueue.map(\.url),
            current: model.current?.url,
            progress: progress,
            isShuffle: model.shuffle,
            repeatMode: repeatMode.rawValue,
            volume: volume
        )
        Task.detached { PlaybackPersistence.save(state) }
    }
}
