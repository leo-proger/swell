//
//  LibraryStore.swift
//  music-player
//

import AppKit
import Observation

/// Медиатека: выбор папки, безопасный (read-only) импорт и поиск.
///
/// Гарантия безопасности: приложение в песочнице с правом `user-selected.read-only`,
/// а весь код только читает файлы. Удалить или изменить пользовательскую музыку
/// невозможно ни случайно, ни намеренно.
@MainActor
@Observable
final class LibraryStore {
    /// Состояние загрузки медиатеки.
    enum LoadState: Equatable {
        case idle
        case loading(done: Int, total: Int)
        case loaded
    }

    private(set) var tracks: [Track] = []
    private(set) var state: LoadState = .idle
    private(set) var folderName: String?
    var searchQuery = ""

    @ObservationIgnored private var folderURL: URL?
    @ObservationIgnored private var scanTask: Task<Void, Never>?

    private let bookmarkKey = "swell.musicFolderBookmark"

    /// Треки с учётом строки поиска — гибкий fuzzy-поиск (буквы по порядку, не подряд)
    /// по названию, исполнителю и альбому. Результаты ранжированы: точнее — выше.
    var filteredTracks: [Track] {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return tracks }
        return tracks
            .compactMap { track -> (track: Track, score: Int)? in
                let haystack = "\(track.title) \(track.artist) \(track.album)"
                guard let score = FuzzySearch.score(query, in: haystack) else { return nil }
                return (track, score)
            }
            .sorted { $0.score > $1.score }
            .map(\.track)
    }

    var isScanning: Bool {
        if case .loading = state { return true }
        return false
    }

    /// Удаляет файл трека **в Корзину** (восстановимо) и убирает его из списка и кэша.
    /// Через `setLibrary` трек уходит и из очереди.
    func deleteFile(_ track: Track) {
        do {
            try FileManager.default.trashItem(at: track.url, resultingItemURL: nil)
            tracks.removeAll { $0.id == track.id }
            if let folder = folderURL {
                LibraryCache.save(tracks, folderPath: folder.path)
            }
        } catch {
            // Не удалось переместить в Корзину — список оставляем как есть.
        }
    }

    // MARK: - Восстановление прошлой папки

    /// Пытается открыть папку, выбранную в прошлый запуск (по security-scoped закладке).
    func restore() async {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            return
        }

        beginAccess(to: url)
        if isStale { saveBookmark(for: url) }
        await loadFolder(url)
    }

    // MARK: - Выбор и обновление папки

    /// Показывает диалог выбора папки и загружает её содержимое.
    func chooseFolder() async {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose your music folder."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        saveBookmark(for: url)
        beginAccess(to: url)
        await loadFolder(url)
    }

    /// Перечитывает текущую папку (например, после добавления новых треков).
    func reload() async {
        guard let url = folderURL else { return }
        await scan(folder: url, showProgress: true)
    }

    /// Мгновенно показывает кэш папки (если есть) и обновляет его в фоне, иначе —
    /// полноценное сканирование с прогрессом.
    private func loadFolder(_ url: URL) async {
        if let cached = LibraryCache.load(folderPath: url.path), !cached.isEmpty {
            tracks = cached
            state = .loaded
            Task { await scan(folder: url, showProgress: false) }
        } else {
            await scan(folder: url, showProgress: true)
        }
    }

    // MARK: - Доступ к папке

    private func beginAccess(to url: URL) {
        if let previous = folderURL, previous != url {
            previous.stopAccessingSecurityScopedResource()
        }
        _ = url.startAccessingSecurityScopedResource()
        folderURL = url
        folderName = url.lastPathComponent
    }

    private func saveBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    // MARK: - Сканирование (read-only)

    private func scan(folder: URL, showProgress: Bool) async {
        scanTask?.cancel()
        let task = Task { await performScan(folder: folder, showProgress: showProgress) }
        scanTask = task
        await task.value
    }

    /// Чтение метаданных идёт в фоне (detached), на главный поток приходят только
    /// готовые пачки треков — поэтому старт и скролл не лагают. По завершении
    /// результат кэшируется.
    private func performScan(folder: URL, showProgress: Bool) async {
        if showProgress { state = .loading(done: 0, total: 0) }

        let files = await Task.detached { MusicFileScanner.audioFiles(in: folder) }.value
        let total = files.count
        guard total > 0 else {
            tracks = []
            state = .loaded
            LibraryCache.save([], folderPath: folder.path)
            return
        }
        if showProgress { state = .loading(done: 0, total: total) }

        let stream = AsyncStream<[Track]> { continuation in
            let task = Task.detached(priority: .userInitiated) {
                var batch: [Track] = []
                batch.reserveCapacity(300)
                for file in files {
                    if Task.isCancelled { break }
                    batch.append(await TrackMetadataReader.read(url: file))
                    if batch.count >= 300 {
                        continuation.yield(batch)
                        batch.removeAll(keepingCapacity: true)
                    }
                }
                if !batch.isEmpty { continuation.yield(batch) }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }

        var collected: [Track] = []
        collected.reserveCapacity(total)
        for await batch in stream {
            if Task.isCancelled { return }
            collected.append(contentsOf: batch)
            if showProgress {
                tracks = collected
                state = .loading(done: collected.count, total: total)
            }
        }

        tracks = collected
        state = .loaded
        LibraryCache.save(collected, folderPath: folder.path)
    }
}
