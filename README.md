# Orbit

Orbit is a voice and text interface for AI coding agents in the Omarchy Shell. It lives on the desktop, reacts to interaction, and shows plain-text or Markdown responses in place.

## Features

- Voice prompts recorded and transcribed directly by Voxtype
- Typed prompts from the desktop overlay
- Support for Agy, Claude Code, Codex, Copilot, Crush, Grok, Hermes, OpenCode, OMP, Ori, and Pi
- Per-agent model and reasoning-effort selection
- Automatic full-screen capture when a prompt asks the agent to inspect the screen
- Markdown responses with headings, lists, code blocks, and tables
- Conversation context from the previous 20 turns
- Drag positioning, nine placement presets
- Cursor-aware eyes, interaction-driven expressions, blinking, and sleep animations
- A persistent local OpenCode server for faster follow-up requests

## Install

```bash
omarchy plugin add https://github.com/ESHAYAT102/orbit.git --enable
```

Open the Orbit bar widget to choose an installed agent, model, size, and position.

## Use

- Left-click Orbit to start or stop recording.
- Right-click Orbit while idle to type a prompt. Press `Enter` to send it or `Esc` to close the input.
- Right-click while recording or thinking to cancel the active operation.
- Drag Orbit to place it freely on the current screen.
- Click a response bubble to dismiss it.
- Left-click the bar widget to open settings.
- Right-click the bar widget to show or hide Orbit.
- Middle-click the bar widget to cancel recording or an active request.
- Use the trash button in settings to clear conversation history.

Orbit detects screen-related requests using prompt phrases. Before taking a full-screen screenshot it hides its own overlay briefly, captures the screen, and restores itself.

After 30 seconds without interaction Orbit becomes drowsy; after 60 seconds it sleeps. Cursor movement or interaction wakes it.

## Remove

Remove the plugin:

```bash
omarchy plugin remove esh.orbit
```

Stop the optional persistent OpenCode server and clear its runtime files:

```bash
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/orbit-opencode-server"
if [ -s "$runtime_dir/server.pid" ]; then
  kill "$(cat "$runtime_dir/server.pid")" 2>/dev/null || true
fi
rm -rf "$runtime_dir"
```

## License

[MIT](LICENSE)

