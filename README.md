# Myna (Flatpak)

<p align="center">
  <img src="https://flatpak.org/img/favicon.svg" width="96" height="96" alt="Flatpak Logo" />
</p>

<p align="center">
  <b>An unofficial Flatpak port of Canonical's <a href="https://github.com/canonical/myna">Myna</a></b><br>
  Fast, local, offline speech-to-text dictation for the Linux desktop.
</p>

<p align="center">
  <a href="https://github.com/vishnudevk/myna/releases/latest/download/io.github.vishnudevk.Myna.flatpak">
    <img src="https://img.shields.io/badge/Download-Latest_.flatpak-4a90e2?style=for-the-badge&logo=flatpak&logoColor=white" alt="Download Latest Flatpak" />
  </a>
  <a href="https://github.com/flathub/flathub/pull/10992">
    <img src="https://img.shields.io/badge/Flathub-PR%20%2310992-4a90e2?style=for-the-badge&logo=flathub&logoColor=white" alt="Flathub Submission" />
  </a>
  <a href="https://github.com/vishnudevk/myna/releases/latest">
    <img src="https://img.shields.io/github/v/release/vishnudevk/myna?style=for-the-badge&logo=github&color=24292e" alt="GitHub Release" />
  </a>
</p>

---

### Quick Install

Download and install the standalone `.flatpak` bundle directly:

```sh
# 1. Download the latest bundle
curl -LO https://github.com/vishnudevk/myna/releases/latest/download/io.github.vishnudevk.Myna.flatpak

# 2. Install
flatpak install --user io.github.vishnudevk.Myna.flatpak

# 3. Launch
flatpak run io.github.vishnudevk.Myna
```

---

Myna is developed and distributed by Canonical as a set of **snap** packages.
This repository ports that packaging to **Flatpak** so Myna can be distributed
on [Flathub](https://flathub.org) and used on any Linux distribution without Snap.

---

## Packages

| Flatpak ID | What it is |
|---|---|
| `io.github.vishnudevk.Myna` | Client app & bundled Whisper backend (Flathub package) |
| `com.canonical.Myna.Whisper` | Whisper inference backend (standalone faster-whisper / CTranslate2) |
| `com.canonical.Myna.Parakeet` | Parakeet TDT 0.6B v3 inference backend (standalone onnxruntime) |

Model weights and GPU runtime ship as **Flatpak extensions**
(equivalent to snap components):

```
com.canonical.Myna.Whisper.Model.Tiny
com.canonical.Myna.Whisper.Model.Base          ← installed by default
com.canonical.Myna.Whisper.Model.Small
com.canonical.Myna.Whisper.Model.LargeV3
com.canonical.Myna.Whisper.Model.LargeV3Turbo
com.canonical.Myna.Whisper.GpuNvidia

com.canonical.Myna.Parakeet.Model.Int8         ← installed by default
com.canonical.Myna.Parakeet.Model.Fp32
com.canonical.Myna.Parakeet.GpuNvidia
```

---

## Snap → Flatpak translation

### IPC: backend socket sharing

In the snap, the inference backend shares its Unix socket with the client
via snapd's **`inference-provider` content interface** — a bind-mounted
directory written by the backend and read by the client.

In Flatpak this is replaced by a shared path in `$XDG_RUNTIME_DIR/myna/`
(both apps declare `--filesystem=xdg-run/myna:create`). The backend writes
a `<name>.env` file beside its socket:

```
MYNA_SOCKET=/run/user/1000/myna/whisper.sock
MYNA_FLATPAK_APP=com.canonical.Myna.Whisper
```

The client's `--backend-dir` flag scans every `*.env` in that directory and
connects to the first live socket — the same discovery logic the daemon uses
in the snap, just with a different directory.

### Model weights: snap components → Flatpak extensions

Snap's **components** (per-model snap archives) map cleanly to Flatpak
**extensions** — independently installable add-ons that contribute a
read-only mount at a declared directory inside the app's `/app/extensions/`.

### All-in-One Flatpak with Bundled Whisper Backend

`io.github.vishnudevk.Myna` bundles both the client (Rust UI, dictation daemon, HUD, status) and the inference backend (`faster-whisper` CTranslate2 Python server). When launched, `myna-app`:

1. Starts `myna-whisper-server` in the background (if not already running).
2. Starts `myna-daemon` in the background (if not already running).
3. Opens the GTK4/Libadwaita Myna Settings GUI (`myna-config`).

### Offline & First-Run Model Provisioning

Models (such as `base` or `tiny`) are stored in `$XDG_DATA_HOME/myna/models/` (`~/.var/app/io.github.vishnudevk.Myna/data/myna/models/`). If no weights exist on first run, `myna-whisper-server` automatically downloads the default model from Hugging Face via `myna-download-model`. Model sizes can also be manually downloaded with:

```sh
flatpak run --command=myna-download-model io.github.vishnudevk.Myna <tiny|base|small|large-v3|large-v3-turbo>
```

### Daemon lifecycle: snap user daemon → systemd user service / auto-launch

The Myna desktop entry runs `myna-app`, which supervises both the daemon and backend. Alternatively, the systemd **user service** installed at `/app/share/systemd/user/io.github.vishnudevk.Myna.service` can be enabled to run Myna at login:

```sh
systemctl --user enable --now io.github.vishnudevk.Myna.service
```

---

## Building in a container

All builds and tests run inside a Podman container. The container installs
Flatpak tooling and runtimes inside the image; **nothing is installed on the
host operating system**.

The build environment is defined in [Containerfile](Containerfile).

### Build

```sh
scripts/container-build.sh
```

For a clean build:

```sh
scripts/container-build.sh --clean
```

Build output is written to `repo/`.

### Test

```sh
scripts/container-test.sh
```

### Release

Pull requests and pushes to `main` run tests only. Installable Flatpak bundles
are built only when a version tag matching `v*` is pushed:

```sh
git tag -a v0.3.1 -m "Myna Flatpak 0.3.1"
git push origin v0.3.1
```

### Interactive shell

```sh
scripts/container-shell.sh
```

### Create an installable bundle

```sh
scripts/container-bundle.sh
```

The bundle is written to `dist/io.github.vishnudevk.Myna.flatpak`.

### GitHub Actions

GitHub Actions builds and tests every pull request and `main` push using the
same Podman entry points. The workflow is defined in
[.github/workflows/ci.yml](.github/workflows/ci.yml) and uploads
`dist/io.github.vishnudevk.Myna.flatpak` as a release artifact.

### Existing wrapper

`scripts/build-flatpak.sh` is kept as a compatibility entry point and now
delegates to `scripts/container-build.sh`.

---

## Agent policy

Agent instructions are in [AGENTS.md](AGENTS.md). In short:

- **All development, build, and test commands must run inside Podman containers.**
- **Do not install packages, runtimes, SDKs, or build tools on the host OS.**
- **Do not run `flatpak-builder`, `flatpak install`, `apt`, `dnf`, `pip`, or `cargo` directly on the host.**

---

## Current Status

### ✅ What is Done & Working

- **All-in-One Flatpak (`io.github.vishnudevk.Myna`):**
  - Bundles the complete client stack: dictation daemon (`myna-desktop`), GTK4 settings UI (`myna-config`), HUD overlay (`myna-hud`), and testbed (`myna-testbed`).
  - Bundles the offline Whisper Speech-to-Text inference server (`faster-whisper` CTranslate2 Python runtime).
- **Build Performance & Caching:**
  - Fast developer build script (`scripts/build-flatpak.sh`) with incremental caching.
  - Container-only development through Podman using `Containerfile` and `scripts/container-*`.
  - Unified single-pass workspace cargo compilation with `lld` linker and parallel release profile optimizations (cold build ~1m 47s, cached rebuild ~24s).
  - Split manifest into `myna` (Rust compilation) and `myna-packaging` (launcher scripts & desktop integration) for instant packaging tweaks.
- **Flatpak Integration Patches (`patches/`):**
  - `0001-flatpak-backend-support.patch`: Skips Snap-specific onboarding in Flatpak, detects models in `$XDG_DATA_HOME/myna/models/`, and reports active engine `faster-whisper-cpu`.
  - `0002-shortcut-desktop-steps.patch`: Replaces generic paragraph with desktop-specific step-by-step instructions for GNOME and KDE Plasma shortcut setup.
  - `0003-flatpak-ibus-pid-check.patch`: Fixes "Typing unavailable" IBus connection failure by bypassing host `/proc/<pid>` checks inside Flatpak sandbox PID namespaces.
- **Audio & Text Injection:**
  - Native PipeWire audio streaming and IBus direct text injection tested and working end-to-end with USB and built-in microphones.
  - Automatic model downloading (`myna-download-model`) on first run.
  - Hotkey toggling via `flatpak run io.github.vishnudevk.Myna myna-toggle` or `flatpak run --command=myna-toggle io.github.vishnudevk.Myna`.

### ⏳ Pending & Known Considerations

- **Bluetooth Headset Profile Switching (WirePlumber / PipeWire):**
  - Myna upstream sets `media.role = "Communication"`, which triggers WirePlumber's `bluetooth.autoswitch-to-headset-profile`.
  - Bluetooth headset profile renegotiation (switching from A2DP stereo to HFP/HSP mono) often takes > 3 seconds, which exceeds Myna's strict 3-second watchdog timer (`SILENCE_TIMEOUT`), triggering `Some audio lost`.
  - *Recommendation / Workaround:* Keep a connected USB or built-in microphone as the default input device in GNOME Sound Settings, or patch `media.role` to `VoiceRecognition`.
- **Standalone Backend & Extensions:**
  - Manifests for decoupled `com.canonical.Myna.Whisper` / `com.canonical.Myna.Parakeet` and CUDA GPU runtime extensions for setups that prefer independent backend containers.
- **Microphone Device Selector in Settings:**
  - Upstream Myna Settings does not currently offer a microphone picker in the UI (it uses the system default PipeWire source unless launched with `--target <node>`).

