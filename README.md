# Degen Radio for Omarchy

An Omarchy bar plugin for [degen-radio](https://github.com/ethereumdegen/degen-radio). It shows live radio metadata, controls playback through MPRIS, and switches between saved stations.

The plugin ID remains `ethereumdegen.spotatui`, and the player command remains `spotatui`, to preserve existing Omarchy installations and desktop integrations.

## Features

- Appears while the `org.mpris.MediaPlayer2.spotatui` service is available.
- Shows the current ICY song title and station name.
- Opens a popup with previous, play/pause, next, and saved-station controls.
- Highlights the active saved station.
- Left-click opens the popup; middle-click toggles playback.
- Mouse wheel cycles saved stations while radio is active.
- Right-click opens or focuses the terminal player.
- Follows the active Omarchy theme.

## Requirements

- Omarchy with the Quickshell plugin system.
- [degen-radio](https://github.com/ethereumdegen/degen-radio) installed so `spotatui` resolves on `PATH`.

Install the player from a clone:

```bash
git clone https://github.com/ethereumdegen/degen-radio.git
cd degen-radio
cargo install --path . --force
```

## Plugin install

```bash
omarchy plugin add https://github.com/ethereumdegen/omarchy-spotatui-plugin.git --enable
omarchy bar move ethereumdegen.spotatui --after omarchy.agents
```

Start the player:

```bash
spotatui
```

## Controls

| Input | Action |
|---|---|
| Hover | Show the current title and station |
| Left click | Open or close the radio popup |
| Middle click | Pause or resume |
| Right click | Open or focus the terminal player |
| Wheel up/down | Previous or next saved station |
| Station row | Switch to that station |

Station rows come from `spotatui radio list --json`. Selecting a row calls `spotatui radio play URL`, which sends standard MPRIS `OpenUri` to the running player. The plugin never edits state files while the player is running.

## Remove

```bash
omarchy plugin remove ethereumdegen.spotatui --yes
```

## Attribution

Derived from Omarchy's MIT-licensed `omarchy.media` plugin.

## License

MIT
