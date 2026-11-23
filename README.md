# ⚡ Decksi for macOS — Pure Internal System Audio RGB & Lyrics Visualizer

> **Decksi** turns your Mac's screen borders into an audio-reactive, ambient RGB lighting experience that dances in real-time with any music application (Apple Music, Spotify, YouTube, SoundCloud, or system audio). Featuring native **Pure Internal System Audio Capture (NO Microphone)** and a dedicated **Blackout Mode** with synchronized lyrics.

---

## 🎧 Pure Internal System Audio (NO Microphone Needed)

- **Native macOS Audio Output Tap**:
  - Decksi uses Apple's native **ScreenCaptureKit & CoreAudio** frameworks to tap the pure digital audio signal playing *internally* out of your Mac.
  - **Zero Microphone Access**: The physical microphone is never opened or listened to. The yellow microphone recording dot in the macOS menu bar will **never** appear.
  - **Crystal-Clear Beat Sync**: No room noise, no typing sounds, no background voices, no fan hum — 100% clean, pure music beat synchronization from Spotify, Apple Music, YouTube in Safari/Chrome, Ableton, or any app.

---

## 🌟 Key Features

### 🌙 1. Blackout Screen Display Mode (`Cmd + Shift + B`)
- Turns your display deep OLED black, leaving **only the glowing, audio-reactive RGB edge lights** active around the screen border.
- Renders large, synchronized Apple Music-style glowing lyrics in the center of the dark screen.
- Press **ESC** or **click anywhere** to immediately exit Blackout Mode and return to your desktop.

### 🎨 2. Six Border Design Styles
1. **✨ Classic Ambient Glow**: Smooth, continuous luminous gradient falloff into the screen.
2. **📊 Equalizer Spectrum Bars**: Physical soundboard audio EQ visualizer bars dancing inward along all 4 borders.
3. **💡 WS2812B Dotted LED Strip**: Individual circular LED beads marching around your bezel like physical addressable RGB lightstrips.
4. **⚡ Cyber Circuit Tracks**: High-tech angular circuit traces with laser runners and data pulse nodes.
5. **💫 Double Neon Laser Rings**: Dual concentric thin laser rings hugging the display.
6. **🌊 Liquid Wave Ribbon**: Undulating fluid audio wave ribbons that ripple with the rhythm.

### ⚡ 3. 100% Metal GPU Hardware Acceleration
- Replaced all CPU software rasterization with native **Metal Core Animation layers (`CALayer`)**.
- CPU usage is **< 1%** with silky smooth **60 FPS / 120 FPS ProMotion**.

---

## ⚡ Quick Start

### Launch Decksi
```bash
open build/Decksi.app
```
*(Or double-click [`build/Decksi.app`](file:///Users/munazimashrafbhat/Downloads/music/build/Decksi.app) in Finder).*

### Keyboard Shortcuts
| Shortcut | Action |
|---|---|
| `Cmd + Shift + B` | **Toggle Blackout Display Mode (RGB + Lyrics Only)** |
| `ESC` or `Click` | **Exit Blackout Mode** |
| `Cmd + Shift + P` | Toggle Edge Lighting ON / OFF |
| `Cmd + ,` | Open Control Panel / Sliders Window |
| `Cmd + Q` | Quit Decksi |
