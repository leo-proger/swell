# Swell

Native macOS music player (the owner needs specific features a stock player can't
give). Display name is **Swell** (Xcode target/folder are still `music-player`).
Modern, lively, beautiful (acrylic blur), minimal. Design reference: **Apple Music
on iOS (mobile)**.

## ⚠️ Safety contract (non-negotiable)

The owner's ~3000-track library lives only on this laptop — accidental loss is
catastrophic. Sandbox is now **read-write** (`files.user-selected.read-write`) because
delete exists, so safety is by discipline, not the OS:
- The ONLY path that writes/deletes user files is the explicit user "Delete" action.
  Scan / metadata / artwork / playback are strictly read-only.
- **Delete = move to Trash** (`FileManager.trashItem`), never permanent `removeItem`.
  Owner has not approved permanent deletion. Always confirm first.
- Cache + playback-state files are written to the app's own sandbox container
  (`AppStorage.supportDirectory()`), never near the user's music.

## Stack & platform

- **SwiftUI**, macOS **26.5 only** (`MACOSX_DEPLOYMENT_TARGET = 26.5`). No back-deployment —
  use the latest **Liquid Glass** APIs (`.buttonStyle(.glass)`, `GlassEffectContainer`,
  `.glassEffect`) freely, no `if #available` guards.
- Swift 5.0 language mode, but **default actor isolation = MainActor**
  (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). Consequence: types/extensions are
  MainActor-isolated unless marked `nonisolated`. Background code (scanner, metadata,
  artwork, the `Track` model) is explicitly `nonisolated`.
- Xcode project uses **synchronized folders** (`PBXFileSystemSynchronizedRootGroup`):
  any `.swift` added under `music-player/` is auto-included. Do **not** hand-edit
  `project.pbxproj` to register files (the one exception: build settings like
  `CODE_SIGN_ENTITLEMENTS`).
- Entitlements: `music-player/music-player.entitlements` (sandbox + user-selected
  read-only + app-scope bookmarks), wired via `CODE_SIGN_ENTITLEMENTS`.

## Architecture (group by responsibility)

```
music-player/
  Models/         Track (nonisolated value type, id = file URL), PlayQueue (nonisolated
                  queue model: history/current/userQueue/sourceQueue), SampleData (preview-only)
  Services/       nonisolated: MusicFileScanner, TrackMetadataReader, ArtworkLoader,
                  ColorExtractor, Persistence (LibraryCache + PlaybackPersistence + AppStorage)
  State/          LibraryStore (folder/bookmark/cache/scan/search/delete), PlayerEngine
                  (AVAudioPlayer + audio/persist; queue logic in PlayQueue, read API in
                  PlayerEngine+Queue), ArtworkProvider (NSCache thumbs)
  DesignSystem/   Theme (tokens), Formatting (timecode), VisualEffectBackground
  Views/          RootView + WelcomeView + 3 zones; Views/Components/ for primitives
```

- **Queue model** (`PlayQueue`, Apple Music iOS 18+): three regions — `history` (played),
  `current` (the one playing), Up Next = `userQueue` (manual: Play Next / Add to Queue) **then**
  `sourceQueue` (library tail). The manual queue plays first and is **never** shuffled — shuffle
  only reorders `sourceQueue`. `advance()` pulls from `userQueue` before `sourceQueue`; `goBack()`
  pushes current back to the future. `jumpTo()` = tap a queue/history track: everything before it
  moves to `history` (tap-history is the reverse). `PlayerEngine` wraps `PlayQueue` and reloads
  audio whenever `current` changes; tap-to-play on the library = `playNow` (asks Clear/Keep when
  the manual queue is non-empty), tap in the queue window = `jumpTo`. No Autoplay (no "similar
  tracks" source for a local library). State persists per-region in `PlaybackState`.
- **Artwork:** list rows lazy-load cached thumbnails (`ArtworkProvider`, ~88px, NSCache 600).
  Perf-critical: thumbnailing is done **off the main thread** via `CGImageSourceCreateThumbnail`
  (never decode/downscale on main), and rows debounce ~120ms before loading so fast scroll skips
  work. Don't add a `.mask(...)` over the `List` (forces per-frame offscreen compositing → lag).
  Now-playing cover + ambient palette load once per track in `RootView` (`ColorExtractor`).
- **Startup & persistence:** `LibraryCache` stores scanned tracks per folder, so launch shows
  the list instantly and re-scans in the background. Scanning reads metadata **off the main
  actor** (`AsyncStream` from a detached task, 300-track batches) — never block main. Player
  load reads file bytes via mmap off-main with a `loadGeneration` guard (fast track switching).
  `PlaybackPersistence` saves queue + current track + position every ~1s and on events (crash-
  safe); `RootView.restoreOnLaunch` restores them. `Track` is `Codable` for both.

- Two `@MainActor @Observable` stores, injected via `.environment(...)`:
  - **`LibraryStore`** — owns `tracks`, `searchQuery`/`filteredTracks`, `state`
    (idle/loading/loaded), the chosen folder + its security-scoped bookmark. Scans in
    batches of 50 with progress. `restore()` on launch reopens last folder.
  - **`PlayerEngine`** — real playback via `AVAudioPlayer`; holds a `PlayQueue` (see Queue model)
    fed from the library via `setLibrary` on `library.tracks` change. Owns isPlaying, progress,
    volume, shuffle, repeat; a 0.2s timer reads `player.currentTime`. Queue mutations live here;
    read-only queue accessors for views are in `PlayerEngine+Queue`.
- Layout = three zones: **top** library tools (folder/reload), **left** search + track list
  (`.ultraThinMaterial`, hidden scrollbar with edge-fade, resizable via `PanelDivider`),
  **right** now-playing + full transport. Artwork loads lazily for the current track only.

## Design language

- Modern, lively, immersive (deliberately not "strict minimalist" — that was rejected).
- **Transparent window + desktop blur** via `NSVisualEffectView` (`.behindWindow`), with an
  **ambient color wash** (`AmbientBackdrop`) derived from the current track's `artworkColors`,
  slowly drifting. Liquid Glass for control clusters on top.
- Accent = **system accent color** (`Theme.accent` → `Color.accentColor`); applied app-wide
  via `.tint(Theme.accent)`. Don't hardcode a brand color.
- Left list sits on `.ultraThinMaterial`; the right now-playing floats over the ambient wash.
- **All timecodes use SF Mono** (`.monoTimecode()`).
- Spacing/radius come from `Theme.Spacing` / `Theme.Radius`, never magic numbers.

## Commands

SwiftLint and `xcodebuild` need full Xcode — export it first:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

xcodebuild -project music-player.xcodeproj -scheme music-player -destination 'platform=macOS' build
swiftformat music-player              # format (write)
swiftformat --lint music-player       # format:check
swiftlint lint --quiet music-player   # quality
```

## Conventions

- **Scale triggers (time to split):** file ~400 lines, view ~150, function ~40, nesting 3.
  Group by feature/responsibility. Rule of three before abstracting (YAGNI).
- **Type safety / boundaries:** value types for models; validate external input at the seam
  (file import, decoding). Narrow, specific error messages.
- **Isolate platform specifics** (AppKit/window/audio) behind a thin seam so the core stays
  portable and testable.
- **Definition of done:** build + `swiftlint` + `swiftformat --lint` green; new pure logic
  gets a test (XCTest/Swift Testing — not set up yet).

## Working language (agent)

- Reason in English. **App UI copy is English** (project override — the owner asked for an
  English app). Chat replies, commit messages, and **code comments stay Russian**. Code
  identifiers stay English.
- **Git commits:** Russian, first word an infinitive verb (`Добавить`/`Исправить`/`Удалить`),
  ≤ 72 chars, atomic. Never commit secrets.
- **Navigation:** prefer LSP for symbols (definition/references/structure/call hierarchy);
  grep for text and as fallback.

## Feature backlog (owner's list — all read-only-safe except where noted)

Done:
- ✅ Per-track context menu (Info / Play next / Add to queue / Delete) — `TrackListView`.
- ✅ Swipe actions (iOS-Music style): leading = To end / Play next, trailing = Delete (confirmed).
- ✅ Queue ops in `PlayerEngine`: `enqueueNext`, `enqueueLast`, queue-preserving `setLibrary`.
- ✅ **Delete moves the file to Trash** (`LibraryStore.deleteFile` → `trashItem`), confirmed via
  alert, then drops it from list/queue/cache. Recoverable; NOT permanent deletion.
- ✅ Library cache + crash-safe playback persistence (queue + position); off-main scan & player load.

Pending:
- Watch the music folder for newly added tracks (auto-refresh).
- Hover prev/next button → tooltip with that track's title + artist.
- Edit track metadata (artist, title, file name, …) — **needs read-write**, do deliberately.
- "Find cover on Google" button — in the tag-editor and on right-click of the artwork area.
- Persist "deleted"/hidden tracks across rescans (currently session-only).
- Guiding principles: 1) minimalism 2) beauty (acrylic blur).

## Tech TODO

- Cache the scanned library (e.g. SwiftData) so 3k tracks don't re-scan every launch;
  parallelize metadata reads; move folder enumeration off the main actor.
- Bump Swift language mode to 6 (resolve strict-concurrency fallout).
- Add a test target + first smoke test, then a pre-commit git hook
  (swiftformat --lint + swiftlint on staged files).
- opus/ogg won't play via `AVAudioPlayer`; add an `AVPlayer` fallback if needed.
