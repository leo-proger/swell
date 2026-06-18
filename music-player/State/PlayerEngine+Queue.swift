//
//  PlayerEngine+Queue.swift
//  music-player
//

import Foundation

/// Доступ к очереди для вью — только чтение модели `PlayQueue`. Мутации очереди и
/// воспроизведения живут в `PlayerEngine`, чтобы перезагрузка аудио шла рядом с ними.
extension PlayerEngine {
    var currentTrack: Track? {
        model.current
    }

    var currentTrackID: Track.ID? {
        model.current?.id
    }

    /// История воспроизведения — секция «History» в окне очереди.
    var history: [Track] {
        model.history
    }

    /// Ручная очередь — секция «Playing Next» в окне очереди.
    var userQueue: [Track] {
        model.userQueue
    }

    /// Контекстный хвост — секция «Continue Playing» в окне очереди.
    var sourceTail: [Track] {
        model.sourceQueue
    }

    /// Есть ли что-то в ручной очереди — вью решает по этому, спрашивать ли Clear/Keep.
    var hasUserQueue: Bool {
        !model.userQueue.isEmpty
    }
}
