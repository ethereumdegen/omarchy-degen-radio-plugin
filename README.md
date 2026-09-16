# Spotatui for Omarchy

An Omarchy bar plugin for [Spotatui](https://github.com/LargeModGames/spotatui). It adds a compact Spotify-style icon beside the Agents widget and uses Spotatui's MPRIS service for live metadata and playback control.

## Features

- Shows only while Spotatui's MPRIS player is available.
- Green bar icon while audio is playing.
- Hover tooltip with the current station/track and artist metadata.
- Click popup with current metadata, artwork when available, and playback controls.
- Right-click opens or focuses the Spotatui TUI.
- Middle-click toggles play/pause.
- Mouse wheel requests previous/next from Spotatui.
- Follows the active Omarchy theme.

For Internet Radio, Spotatui currently publishes the station as the MPRIS title and the live song metadata as the artist. This plugin displays those fields as provided.

## Requirements

- Omarchy with the Quickshell-based shell/plugin system.
- [Spotatui](https://github.com/LargeModGames/spotatui) built with Linux MPRIS support.
- Spotatui must be running before the icon appears.

## Install

```bash
omarchy plugin add https://github.com/ethereumdegen/omarchy-spotatui-plugin.git --enable
omarchy bar move ethereumdegen.spotatui --after omarchy.agents
```

Start Spotatui:

```bash
spotatui
```

The plugin replaces Omarchy's stock `omarchy.media` widget with a Spotatui-specific view while installed. It does not read Spotify credentials or call Spotify APIs; all live playback data comes from `org.mpris.MediaPlayer2.spotatui` on the user D-Bus.

## Controls

| Input | Action |
|---|---|
| Hover | Show current station/track tooltip |
| Left click | Open or close the now-playing popup |
| Middle click | Play/pause |
| Right click | Open or focus Spotatui |
| Wheel up/down | Previous/next when the active Spotatui source supports it |

The popup also provides previous, play/pause, and next buttons.

## Remove

```bash
omarchy plugin remove ethereumdegen.spotatui --yes
```

## Roadmap: radio station control

The next useful step is station switching from the popup. It should be implemented without editing Spotatui's `state.yml` behind the running process, which could race Spotatui's own persistence and lose changes.

### 1. Add a supported Spotatui control API

Contribute a small D-Bus API upstream to the already-running Spotatui process:

- `ListRadioStations()` returns configured and saved station names and stream URLs.
- `PlayRadioStation(url)` routes a `radio:<url>` request through Spotatui's existing radio dispatcher.
- `SearchRadioStations(query)` exposes its existing radio-browser.info search.
- `SaveRadioStation(name, url)` and `RemoveRadioStation(url)` use Spotatui's own persistence path.
- Signals report station-list changes, tune-in progress, and actionable playback errors.

Also wire standard MPRIS `OpenUri` for `radio:` URIs. MPRIS already exposes play/pause and metadata, but Spotatui 0.42 does not currently connect `OpenUri`, and previous/next intentionally do nothing for live radio.

### 2. Add the station picker to this plugin

Extend the popup with:

- Saved-station rows with the active station highlighted.
- Click or Enter to tune in.
- `j`/`k` navigation matching other Omarchy panels.
- Search backed by Spotatui's radio-browser integration.
- Save/remove actions that call Spotatui rather than modifying YAML directly.
- Busy and error states while a stream connects.

### 3. Add radio-specific controls

- Replace meaningless previous/next buttons during live radio with station previous/next.
- Show `LIVE`, codec, bitrate, and country when Spotatui publishes them.
- Preserve play/pause, volume, artwork, and now-playing metadata.
- Optionally pin favorite stations as quick actions.

### 4. Verification gates

- Switching stations changes audio and MPRIS metadata atomically.
- Failed or slow streams leave the previous station usable and show the real error.
- Saved-station mutations survive restart without corrupting `state.yml`.
- Spotify, YouTube, local-file, and Subsonic playback remain unaffected.
- The widget hides cleanly when Spotatui exits and returns when it restarts.

## Attribution

This plugin is derived from Omarchy's MIT-licensed `omarchy.media` plugin and specializes it for Spotatui.

## License

MIT
