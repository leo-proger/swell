<p align="center">
  <img src="music-player/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="Swell icon" />
</p>

<h1 align="center">Swell</h1>

<p align="center">
  <b>A native, beautiful music player for macOS — built with SwiftUI &amp; Liquid Glass.</b><br/>
  Minimal, lively and fast on your own local library.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2026.5-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Platform: macOS 26.5" />
  <img src="https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift" />
  <img src="https://img.shields.io/badge/SwiftUI-0A84FF?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Liquid%20Glass-8E8E93?style=for-the-badge" alt="Liquid Glass" />
  <img src="https://img.shields.io/badge/license-MIT-22C55E?style=for-the-badge" alt="License: MIT" />
</p>

---

**Swell** is a hand-crafted macOS music player for people who keep their music as files, not subscriptions. Point it at a folder and it gives you a fast, gorgeous way to listen — a transparent, blurred window with an ambient color wash pulled from the current cover, and an Apple Music–style queue underneath.

No accounts. No telemetry. No cloud. Just your library and a beautiful player.

## 🎯 Why Swell?

<table>
  <tr>
    <td>🎨 <b>Beautiful</b></td>
    <td>Acrylic blur, Liquid Glass controls and a living background that drifts with your music — not another gray list.</td>
  </tr>
  <tr>
    <td>🍏 <b>Native</b></td>
    <td>Built entirely with SwiftUI for Apple Silicon. No Electron, no web views, no bundled browser.</td>
  </tr>
  <tr>
    <td>🪶 <b>Minimal</b></td>
    <td>Two panes, the controls you need, nothing you don't.</td>
  </tr>
  <tr>
    <td>🔒 <b>Private</b></td>
    <td>Sandboxed and offline. Your music never leaves your Mac.</td>
  </tr>
</table>

## ✨ Features

- **Liquid Glass design** — a transparent window with desktop blur and an ambient color wash drawn from the current track's artwork.
- **Apple Music–style queue** — History, Now Playing and Up Next, with a manual queue (Play Next / Add to Queue) that always plays first and is never shuffled.
- **Real shuffle** — shuffles your whole library, not just a random starting point.
- **Fuzzy search** — type a few letters in order (`rhcp` → Red Hot Chili Peppers) and the right track floats up.
- **Instant launch** — your library is cached, so it opens right away and refreshes in the background.
- **Crash-safe playback** — your queue and playback position survive quits and crashes.
- **Smooth at scale** — the heavy work happens in the background, so a library with thousands of tracks scrolls without a stutter.
- **Safe by design** — the only action that ever touches your files is an explicit Delete, and it moves them to the Trash, never permanently.
- **System integration** — the macOS Now Playing widget and media keys just work.

## 🧱 Built with

- **SwiftUI** — the entire interface
- **Liquid Glass** — the translucent, frosted controls and panels
- **AVFoundation** — audio playback
- **AppKit** — the transparent window and desktop blur

## 🚀 Getting started

**Requirements:** macOS **26.5** and Xcode (full install).

```sh
git clone https://github.com/leo-proger/swell.git
cd swell
open music-player.xcodeproj   # then press ⌘R
```

Prefer the terminal?

```sh
scripts/run.sh            # build & run (Debug)
scripts/run.sh Release    # build & run (Release)
```

On first launch, pick your music folder — Swell remembers it and reopens it next time.

## 🗂️ Project layout

```
music-player/
├─ Models/        the music library and the play queue
├─ Services/      scanning, metadata, artwork, search, persistence
├─ State/         library and playback state
├─ DesignSystem/  theme, formatting and visual effects
└─ Views/         the interface
```

## 🗺️ Roadmap

- [ ] Watch the music folder for newly added tracks
- [ ] Edit track metadata (title, artist, file name…)
- [ ] "Find cover art" from the web
- [ ] Hover the prev/next buttons to preview that track
- [ ] Persist hidden / removed tracks across rescans

## 📄 License

Released under the [MIT License](LICENSE) © leo-proger.

<p align="center"><sub>Made with SwiftUI and a lot of blur.</sub></p>
