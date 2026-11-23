# ⚡ Decksi for macOS — Pure Internal Audio RGB, Cinema Video Ambilight & 3D Lyrics

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?style=flat&logo=apple)](https://github.com/munazimashraf/Decksi)
[![Metal GPU](https://img.shields.io/badge/GPU-Metal%20Accelerated-orange?style=flat)](https://github.com/munazimashraf/Decksi)
[![Zero Mic](https://img.shields.io/badge/Audio-Pure%20Internal%20(No%20Mic)-brightgreen?style=flat)](https://github.com/munazimashraf/Decksi)
[![License](https://img.shields.io/badge/License-MIT-purple?style=flat)](https://github.com/munazimashraf/Decksi)

> **Decksi** transforms your Mac display into an immersive ambient RGB visualizer that pulses in real-time with internal audio, synchronizes edge lighting with live video playback (**Cinema Ambilight**), and turns your screen into a breathtaking **3D Classical Lyrics Theater in Blackout Mode**.

Inspired by [Prixm](https://prixm.in/), engineered natively for macOS with **Metal GPU hardware acceleration (< 1% CPU)** and **Zero physical microphone access**.

---

## 🎬 1. Cinema Video Ambilight (Real-Time Video Screen Light Sync)

Press **`Cmd + Shift + V`** to activate real-time **Video Light Sync**. When playing any video (YouTube, Netflix, Apple TV, VLC, Twitch, movies, or gaming), Decksi dynamically samples and matches the edge lighting of your screen:

- **28-Zone Multi-Border Analysis**:
  - **8 Zones** along the Top Border
  - **8 Zones** along the Bottom Border
  - **6 Zones** along the Left Border
  - **6 Zones** along the Right Border
- **Intelligent Letterbox & Black-Bar Detection**: Automatically ignores black bars on widescreen 21:9 / 2.39:1 Cinemascope films and 4:3 videos, projecting true scene colors.
- **Cinematic Saturation & Gamma Boost**: Applies 1.35x saturation enhancement and gamma curve adjustments so dark scenes produce rich, vibrant ambient halos.
- **Audio-Ambilight Fusion**: Scene colors blend directly with internal audio dynamics — the lighting glows, widens, and pulses with the soundtrack's bass drops and beats.
- **Temporal LERP Smoothing**: Exponential moving average filtering eliminates jitter and strobe effects for fluid, cinematic transitions.

---

## 🎧 2. Pure Internal System Audio (NO Microphone Needed)

- **Native Digital Audio Tap**: Uses Apple's modern `ScreenCaptureKit` pipeline to capture pure digital PCM audio directly from macOS output.
- **Zero Microphone Access**: The physical microphone is never opened. The macOS orange/yellow recording dot will **never** appear.
- **Crystal-Clear Audio Sync**: Eliminates fan hum, keyboard clicks, typing noise, and room echo. Taps directly into Spotify, Apple Music, YouTube in Safari/Chrome, SoundCloud, and media players.
- **Automatic Fallback Simulator**: If permissions are pending, an ambient 124 BPM music rhythm generator keeps your borders glowing smoothly.

---

## 🏛️ 3. Blackout Display Mode & 3D Classical Lyrics (`Cmd + Shift + B`)

Press **`Cmd + Shift + B`** to enter OLED Blackout Mode: your entire display goes jet black, leaving only the glowing RGB edge borders and centered, synchronized lyrics.

Press **`Tab`** in Blackout Mode to switch between **4 Classical 3D Perspective View Angles**:

| Angle | Description |
|---|---|
| **🏛️ Classical 3D Amphitheater** | Perspective tilted horizon with mirrored reflections across a polished marble floor |
| **🎭 Grand Opera House Stage** | Theatrical overhead spotlights with majestic Roman serif typography |
| **💿 Oblique 3D Turntable Lounge** | Tilted vinyl record deck, gleaming tonearm, and frosted obsidian plaque with gilded gold trim |
| **🎼 Tilted 3D Chamber Manuscript** | Classical acoustic sheet style with warm ambient gold filigree |

*(Press `ESC` or click anywhere to exit Blackout Mode).*

---

## 🎨 4. Six Border Design Styles

Decksi offers 6 distinct border rendering styles:

1. **✨ Classic Ambient Glow**: Smooth, continuous radiant glow projecting inward from the bezel.
2. **📊 Equalizer Spectrum Bars**: Multi-band soundboard audio EQ visualizer bars dancing along all 4 screen edges.
3. **💡 WS2812B Dotted LED Strip**: Individual circular addressable LED beads marching around your display.
4. **⚡ Cyber Circuit Tracks**: High-tech angular circuit traces with laser runners and animated data pulse nodes.
5. **💫 Double Neon Laser Rings**: Dual concentric thin laser rings hugging the display perimeter.
6. **🌊 Liquid Wave Ribbon**: Fluid undulating audio wave ribbons that ripple with the rhythm.

---

## 🌈 5. Color Presets

Decksi includes 10 built-in color palettes selectable from the Menu Bar:
1. **🌈 Prism RGB Rainbow Spectrum**
2. **⚡ Cyberpunk 2077 (Cyan & Pink)**
3. **🔥 Sunset Ember (Crimson & Gold)**
4. **🌌 Cosmic Aurora (Emerald & Violet)**
5. **☀️ Solar Plasma / Firestorm (Gold & Magma)**
6. **🧪 Toxic Matrix (Acid Lime & Emerald)**
7. **🌴 Synthwave Sunset (80s Purple & Peach)**
8. **🎵 Dynamic Music Sync (Spotify/Apple Music)**
9. **⚪ Pure Hyper-White (Clean Halo)**
10. **🎬 Cinema Ambilight (Video Screen Light Sync)**

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| **`Cmd + Shift + V`** | **Toggle Cinema Video Ambilight (Screen Edge Sync)** |
| **`Cmd + Shift + B`** | **Toggle Blackout Display Mode (RGB + Lyrics Only)** |
| **`Tab`** *(in Blackout)* | **Cycle 3D Classical Perspective View Angle** |
| **`ESC`** or **Click** | **Exit Blackout Mode** |
| **`Cmd + Shift + P`** | **Toggle Edge Lighting ON / OFF** |
| **`Cmd + ,`** | **Open Control Panel & Preferences** |
| **`Cmd + Q`** | **Quit Decksi** |

---

## 🛠️ Building & Running

### Requirements
- macOS 13.0+ (Ventura, Sonoma, Sequoia)
- Apple Silicon (M1/M2/M3/M4) or Intel x86_64 Mac
- Xcode Command Line Tools (`xcode-select --install`)

### Compile
```bash
./build.sh
```

### Launch
```bash
./run.sh
```
*(Or launch `build/Decksi.app` directly).*

---

## 🔒 Permission Setup (First Launch)

On initial launch, macOS will present a permission dialog:
> *"Decksi" would like to record this computer's screen and audio.*

1. Click **Open System Settings** (or navigate to **System Settings → Privacy & Security → Screen & System Audio Recording**).
2. Toggle the switch next to **Decksi** to **ON**.
3. Decksi will instantly transition to pure internal digital audio capture and real-time screen edge ambilight analysis with **zero microphone access**.

---

## 📄 License

MIT License — free for personal and commercial use.
