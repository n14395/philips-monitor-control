# Philips Monitor Control

A cross-platform application for controlling Philips monitors over DDC/CI. Adjust brightness, contrast, color temperature, input sources, MultiView (PIP/PBP), audio, and system settings — all from software, without touching the physical OSD buttons.

The DDC/CI VCP codes used by this project were reverse-engineered from Philips SmartControl 7.0.0 .NET assemblies. On Linux the application wraps [ddcutil](https://www.ddcutil.com/) to communicate with the monitor over I2C; on macOS it uses native IOKit APIs for direct DDC/CI access.

> **Disclaimer:** This project is **not affiliated with, endorsed by, or associated with Koninklijke Philips N.V. or any of its subsidiaries**. "Philips" and "SmartControl" are trademarks of their respective owners. The DDC/CI VCP codes used here were independently reverse-engineered for interoperability purposes.
>
> This software is provided **as-is, with no warranties or guarantees of any kind**, express or implied. The author assumes no responsibility or liability for any damage to hardware, software, or data resulting from the use of this code. **Use it at your own risk.**
>
> This project has only been tested on the **Philips BDM4037U**. Behavior on other monitors is unknown and untested — it may not work correctly, or at all, on other models.

## Features

- **Display settings** — brightness, contrast, color temperature, gamma, SmartImage presets, display scaling
- **Color management** — independent red, green, and blue gain controls
- **MultiView** — Picture-in-Picture (PIP) with configurable size and position, Picture-by-Picture (PBP) modes, source swapping
- **Audio** — volume and mute
- **Input switching** — select main and secondary input sources from VGA, DVI, HDMI 1–3, DisplayPort 1–2, USB-C 1–2
- **System controls** — power mode, power LED brightness, OSD language, resolution notifier, input auto-detect
- **Monitor info** — firmware version and display usage time
- **Factory reset** and **VGA auto-setup** actions
- **Three interfaces** — GTK4/Libadwaita GUI (Linux), SwiftUI GUI (macOS), and a Linux CLI

## Platforms

| Platform | Interface | Toolkit |
|----------|-----------|---------|
| Linux    | GUI       | GTK 4 / Libadwaita (Python) |
| Linux    | CLI       | Python 3 (terminal) |
| macOS    | GUI       | SwiftUI (Swift) |

## Installation

The easiest way to install is to grab a pre-built package from the [GitHub Releases](https://github.com/n14395/philips-monitor-control/releases) page:

- **Linux** — download the `.flatpak` bundle, then install with `flatpak install --user <file>.flatpak`
- **macOS** — download the `.dmg`, open it, and drag the app to Applications

To build from source instead, see the sections below.

## Prerequisites

### Linux

The recommended way to run on Linux is via Flatpak, which bundles all dependencies automatically. To build the Flatpak you need:

- [Flatpak](https://flatpak.org/) and `flatpak-builder`
- The GNOME 50 runtime and SDK (installed automatically by the build script)

For running outside of Flatpak:

- Python 3
- GTK 4 and Libadwaita (with GObject Introspection bindings)
- [ddcutil](https://www.ddcutil.com/)
- Access to `/dev/i2c-*` devices (your user must be in the `i2c` group, or run as root)

### macOS

- Apple Silicon Mac (M1 or later)
- macOS 14 (Sonoma) or later
- Swift 5.9+ (included with Xcode 15+)
- Optional: `librsvg` (`brew install librsvg`) for app icon generation
- **Important:** The built-in HDMI port on M1 and entry-level M2 Macs does not support DDC/CI. Connect your monitor via **USB-C** (DisplayPort Alt Mode) or a USB-C to DisplayPort/HDMI adapter instead.

## Building

### Linux (Flatpak)

```bash
./build-flatpak.sh 1.0.0
```

This produces a Flatpak bundle at `src/com.n14395.monitorcontrol-1.0.0.flatpak`. Install and run it with:

```bash
flatpak install --user com.n14395.monitorcontrol-1.0.0.flatpak
flatpak run com.n14395.monitorcontrol
```

### macOS

```bash
./build-macos.sh 1.0.0
```

This compiles the Swift binary, assembles a `.app` bundle, and (on macOS) creates a `.dmg` disk image with a drag-to-Applications layout.

### CLI (Linux, no build required)

The CLI can be run directly without building:

```bash
cd Linux
./philips-multiview.py status
./philips-multiview.py set brightness 70
./philips-multiview.py pip --source hdmi2 --size large --location top-right
```

Run `./philips-multiview.py --help` for the full list of commands and options.

## Project Structure

```
src/
├── build-flatpak.sh               # Linux Flatpak build script
├── build-macos.sh                 # macOS build script
├── Linux/
│   ├── philips-multiview.py       # CLI interface
│   ├── multiview_ddc.py           # DDC/CI logic and VCP constants
│   └── philips-multiview-gtk.py   # GTK4/Libadwaita GUI
├── MacOS/
│   ├── Package.swift              # Swift package manifest
│   ├── Makefile
│   ├── Info.plist
│   └── Sources/
│       ├── PhilipsMultiViewApp.swift   # SwiftUI application
│       └── DDCUtil.swift               # Swift ddcutil wrapper
└── assets/
    ├── com.n14395.monitorcontrol.desktop      # Desktop entry
    ├── com.n14395.monitorcontrol.svg          # Application icon
    ├── com.n14395.monitorcontrol.yml          # Flatpak manifest
    └── com.n14395.monitorcontrol.metainfo.xml # AppStream metadata
```

## License

This project is licensed under the [GNU General Public License v3.0 or later](https://www.gnu.org/licenses/gpl-3.0.html).

