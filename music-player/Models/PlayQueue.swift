//
//  PlayQueue.swift
//  music-player
//

import Foundation

/// Чистая модель очереди в стиле Apple Music (iOS 18+). Без звука и без UI —
/// только данные и переходы, поэтому легко тестируется и спокойно живёт в фоне
/// (`nonisolated`). Платформенная часть (AVAudioPlayer, персист) — в `PlayerEngine`.
///
/// Три логических региона:
/// • `history`   — уже сыгранное (старое первым, недавнее последним);
/// • `current`   — ровно один текущий трек, граница между прошлым и будущим;
/// • Up Next     — будущее = `userQueue` (ручная очередь) + `sourceQueue` (хвост контекста).
///
/// Ручная очередь (`userQueue`, добавленная через Play Next / Add to Queue) играет
/// раньше контекстного хвоста и НЕ перемешивается шаффлом — шаффл переставляет только
/// `sourceQueue`. Так воспроизводится поведение, которое пользователи Apple Music
/// описывают как «Play Next идёт своим блоком, а не вперемешку с альбомом».
nonisolated struct PlayQueue {
    /// Что произошло с текущим треком после пересборки контекста (`setSource`).
    enum SourceUpdate {
        /// Текущий трек не изменился — аудио перезагружать не нужно.
        case unchanged
        /// Был пустой плеер, теперь предвыбран первый трек (без автозапуска).
        case preselected
        /// Текущий трек исчез из медиатеки — движок должен загрузить новый текущий.
        case currentReplaced
    }

    /// Максимум записей истории — чтобы список не рос бесконечно.
    private static let historyLimit = 100

    private(set) var history: [Track] = []
    private(set) var current: Track?
    /// Ручная очередь: Play Next / Add to Queue. Приоритетна, не шаффлится.
    private(set) var userQueue: [Track] = []
    /// Контекстный хвост (остаток медиатеки). Его и только его трогает шаффл.
    private(set) var sourceQueue: [Track] = []
    /// Полный исходный контекст (медиатека) — источник пересборки хвоста и шаффла.
    private(set) var source: [Track] = []
    /// Шаффл применяется только к `sourceQueue`.
    private(set) var shuffle = false

    /// Будущее в порядке воспроизведения: сперва ручные треки, затем хвост контекста.
    var upNext: [Track] {
        userQueue + sourceQueue
    }

    // MARK: - Контекст (медиатека)

    /// Переопределяет контекст (новый список медиатеки) и сверяет с ним все регионы:
    /// удаляет пропавшие треки, дописывает новые в хвост, при необходимости выбирает
    /// новый текущий трек. Возвращает, что стало с текущим (нужна ли перезагрузка аудио).
    @discardableResult
    mutating func setSource(_ tracks: [Track]) -> SourceUpdate {
        let previousID = current?.id
        source = tracks
        let present = Set(tracks.map(\.id))
        history = history.filter { present.contains($0.id) }

        // Текущий трек исчез из медиатеки → берём следующий доступный в порядке игры.
        if let cur = current, !present.contains(cur.id) {
            current = upNext.first { present.contains($0.id) }
        }
        let currentID = current?.id
        userQueue = userQueue.filter { present.contains($0.id) && $0.id != currentID }
        sourceQueue = sourceQueue.filter { present.contains($0.id) && $0.id != currentID }

        if current == nil {
            // Холодный старт или опустевшая медиатека: предвыбираем первый трек.
            let pool = excludingUserQueue(shuffle ? tracks.shuffled() : tracks)
            current = pool.first
            sourceQueue = Array(pool.dropFirst())
        } else {
            // Новые (только что отсканированные) треки — в конец контекстного хвоста.
            var known = Set(history.map(\.id))
            known.formUnion(userQueue.map(\.id))
            known.formUnion(sourceQueue.map(\.id))
            if let id = current?.id { known.insert(id) }
            let added = tracks.filter { !known.contains($0.id) }
            sourceQueue.append(contentsOf: shuffle ? added.shuffled() : added)
        }

        let newID = current?.id
        if newID == previousID { return .unchanged }
        return previousID == nil ? .preselected : .currentReplaced
    }

    // MARK: - Запуск воспроизведения

    /// «Играть сейчас» по тапу в медиатеке: текущим становится `track`, контекстный
    /// хвост — остаток медиатеки после него (или вся медиатека вперемешку при шаффле).
    /// `keepUserQueue` решает судьбу ручной очереди (в Swell выбирает пользователь).
    mutating func playNow(_ track: Track, keepUserQueue: Bool) {
        pushCurrentToHistory()
        current = track
        if !keepUserQueue { userQueue.removeAll() }
        userQueue.removeAll { $0.id == track.id }
        // Хвост строим из медиатеки, но исключаем ручную очередь — иначе один трек
        // оказался бы и в «Playing Next», и в «Continue Playing» (сыграл бы дважды).
        let tail = shuffle ? source.filter { $0.id != track.id }.shuffled() : tailAfter(track, in: source)
        sourceQueue = excludingUserQueue(tail)
    }

    /// «Перемешать всё» (кнопка-шаффл в шапке списка): реально тасует всю медиатеку и
    /// включает режим шаффла. Свежий старт — ручная очередь сбрасывается.
    mutating func playRandom() {
        guard !source.isEmpty else { return }
        shuffle = true
        userQueue.removeAll()
        let ordered = source.shuffled()
        pushCurrentToHistory()
        current = ordered.first
        sourceQueue = Array(ordered.dropFirst())
    }

    // MARK: - Навигация

    /// Переход к следующему треку: сперва ручная очередь, затем контекст. `false`,
    /// если будущее пусто (конец очереди — дальше решает движок по repeat).
    @discardableResult
    mutating func advance() -> Bool {
        guard !upNext.isEmpty else { return false }
        pushCurrentToHistory()
        current = userQueue.isEmpty ? sourceQueue.removeFirst() : userQueue.removeFirst()
        return true
    }

    /// Переход к предыдущему треку из истории. Текущий возвращается в начало будущего
    /// (играет сразу после). `false`, если истории нет.
    @discardableResult
    mutating func goBack() -> Bool {
        guard let previous = history.popLast() else { return false }
        if let cur = current { userQueue.insert(cur, at: 0) }
        current = previous
        // Если этот трек ещё и лежал в будущем — убираем, чтобы текущий не задвоился.
        removeFromQueue(previous)
        return true
    }

    /// Тап по треку в окне очереди.
    /// • Будущее: всё до выбранного уходит в историю (как быстрый скип), выбранный
    ///   становится текущим, хвост сохраняется.
    /// • История: откат назад — выбранный трек и всё, что игралось после него (включая
    ///   текущий), возвращаются в начало хвоста и снова играют по порядку.
    mutating func jumpTo(_ track: Track) {
        if let index = userQueue.firstIndex(where: { $0.id == track.id }) {
            pushCurrentToHistory()
            userQueue[..<index].forEach { appendHistory($0) }
            let chosen = userQueue[index]
            userQueue.removeSubrange(...index)
            current = chosen
        } else if let index = sourceQueue.firstIndex(where: { $0.id == track.id }) {
            pushCurrentToHistory()
            userQueue.forEach { appendHistory($0) }
            userQueue.removeAll()
            sourceQueue[..<index].forEach { appendHistory($0) }
            let chosen = sourceQueue[index]
            sourceQueue.removeSubrange(...index)
            current = chosen
        } else if let index = history.firstIndex(where: { $0.id == track.id }) {
            let target = history[index]
            var returning = Array(history[(index + 1)...])
            if let cur = current { returning.append(cur) }
            history.removeSubrange(index...)
            current = target
            // Возвращаемые треки (промежуточные + бывший текущий) — в начало хвоста,
            // сняв их прошлые копии из обеих зон, чтобы ничего не задвоилось.
            let movedIDs = Set(returning.map(\.id)).union([target.id])
            userQueue.removeAll { movedIDs.contains($0.id) }
            sourceQueue.removeAll { movedIDs.contains($0.id) }
            sourceQueue.insert(contentsOf: returning, at: 0)
        }
    }

    // MARK: - Ручная очередь

    /// Play Next — в начало ручной очереди (перед уже добавленными вручную треками).
    mutating func playNext(_ track: Track) {
        guard track.id != current?.id else { return }
        removeFromQueue(track)
        userQueue.insert(track, at: 0)
    }

    /// Add to Queue — в конец ручной очереди, но ПЕРЕД хвостом контекста.
    mutating func addToQueue(_ track: Track) {
        guard track.id != current?.id else { return }
        removeFromQueue(track)
        userQueue.append(track)
    }

    /// Убирает трек из будущего (обе зоны), не трогая историю и текущий.
    mutating func removeFromQueue(_ track: Track) {
        userQueue.removeAll { $0.id == track.id }
        sourceQueue.removeAll { $0.id == track.id }
    }

    /// Clear на экране очереди: чистит только ручную очередь, хвост контекста остаётся
    /// (поведение Apple Music — продолжаем играть медиатеку).
    mutating func clearUserQueue() {
        userQueue.removeAll()
    }

    mutating func clearHistory() {
        history.removeAll()
    }

    mutating func moveUserQueue(fromOffsets source: IndexSet, toOffset destination: Int) {
        userQueue = Self.moved(userQueue, fromOffsets: source, toOffset: destination)
    }

    mutating func moveSourceQueue(fromOffsets source: IndexSet, toOffset destination: Int) {
        sourceQueue = Self.moved(sourceQueue, fromOffsets: source, toOffset: destination)
    }

    // MARK: - Шаффл и повтор

    /// Включает/выключает шаффл: переставляет только контекстный хвост, не трогая
    /// историю, текущий трек и ручную очередь.
    mutating func setShuffle(_ on: Bool) {
        guard on != shuffle else { return }
        shuffle = on
        if on {
            sourceQueue.shuffle()
        } else {
            let order = Dictionary(
                source.enumerated().map { ($1.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            sourceQueue.sort { (order[$0.id] ?? .max) < (order[$1.id] ?? .max) }
        }
    }

    /// Repeat All на конце очереди: пересобирает хвост из всего контекста заново.
    /// Ручную очередь не трогаем (она сыграет первой) и исключаем её из хвоста.
    mutating func restartContext() {
        let pool = excludingUserQueue(shuffle ? source.shuffled() : source)
        guard let first = pool.first else { return }
        pushCurrentToHistory()
        current = first
        sourceQueue = Array(pool.dropFirst())
    }

    // MARK: - Восстановление

    /// Срез регионов для восстановления из персиста (см. `restore`).
    struct Snapshot {
        var history: [Track] = []
        var current: Track?
        var userQueue: [Track] = []
        var sourceQueue: [Track] = []
        var source: [Track] = []
        var shuffle = false
    }

    /// Заполняет модель восстановленным состоянием (из персиста). Без логики переходов —
    /// просто кладёт уже собранные движком регионы на место.
    mutating func restore(_ snapshot: Snapshot) {
        history = snapshot.history
        current = snapshot.current
        userQueue = snapshot.userQueue
        sourceQueue = snapshot.sourceQueue
        source = snapshot.source
        shuffle = snapshot.shuffle
    }

    // MARK: - Приватное

    private mutating func pushCurrentToHistory() {
        guard let cur = current else { return }
        appendHistory(cur)
    }

    private mutating func appendHistory(_ track: Track) {
        history.removeAll { $0.id == track.id }
        history.append(track)
        if history.count > Self.historyLimit {
            history.removeFirst(history.count - Self.historyLimit)
        }
    }

    private func tailAfter(_ track: Track, in list: [Track]) -> [Track] {
        guard let index = list.firstIndex(where: { $0.id == track.id }) else { return [] }
        return Array(list[(index + 1)...])
    }

    /// Убирает из списка треки, уже лежащие в ручной очереди, — чтобы трек не задвоился
    /// между «Playing Next» и контекстным хвостом.
    private func excludingUserQueue(_ tracks: [Track]) -> [Track] {
        let userIDs = Set(userQueue.map(\.id))
        return tracks.filter { !userIDs.contains($0.id) }
    }

    /// Семантика SwiftUI `move(fromOffsets:toOffset:)` без зависимости от SwiftUI:
    /// вынимаем перемещаемые элементы и вставляем перед позицией назначения.
    private static func moved<T>(
        _ array: [T],
        fromOffsets source: IndexSet,
        toOffset destination: Int
    ) -> [T] {
        var result = array
        let moving = source.sorted().map { array[$0] }
        for index in source.sorted(by: >) {
            result.remove(at: index)
        }
        let insertAt = destination - source.filter { $0 < destination }.count
        result.insert(contentsOf: moving, at: insertAt)
        return result
    }
}
