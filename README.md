# Claude Usage Bar

A tiny native macOS **menu-bar app** that shows your Claude Code usage limits at a glance —
right next to the Wi-Fi and battery icons, so you never have to stop and run `/usage` to
find out how much of your session or weekly limit is left.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

<!-- Add a screenshot at docs/screenshot.png, then uncomment:
![Claude Usage Bar](docs/screenshot.png)
-->

## What it shows

The menu bar displays one live percentage (your current session by default). Click it for the
full picture — the same numbers as Claude Code's `/usage`:

- **Session · 5 hours** — how much of the rolling 5-hour window you've used, and when it resets
- **Weekly · all models** — your weekly limit across all models
- **Weekly · <model>** — any model-scoped weekly limits your plan has (e.g. a separate weekly cap)

Each with a colored meter (green → yellow → red) and a reset time. There's also a small
"Activity today" section showing token counts per model, read from your local logs.

## Why

The usage numbers are only a `/usage` command away — but that means stopping what you're doing,
switching to a Claude Code session, and typing it. This keeps the one number you care about
("am I about to hit my limit?") visible all the time, and one click away from the full breakdown.

## Requirements

- **macOS 14 (Sonoma) or later**
- **Claude Code**, signed in with a subscription (Pro, Max, Team, or Enterprise)
- Apple's Swift toolchain to build it — install **Xcode** from the App Store, or the lighter
  Command Line Tools with `xcode-select --install`

## Install

Build it from source (takes a few seconds):

```sh
git clone https://github.com/bilalahmadj110/ClaudeUsageBar.git
cd ClaudeUsageBar
./build.sh
open ClaudeUsageBar.app
```

The gauge appears in your menu bar. To keep it there permanently:

```sh
mv ClaudeUsageBar.app /Applications/
open /Applications/ClaudeUsageBar.app
```

Then open **Settings** (the gear in the dropdown) → turn on **Launch at login**.

> Because you build and run it yourself, macOS treats it as your own software — there's no
> "unidentified developer" warning to click through.

## Settings

- **Menu bar shows** — Session, Weekly, or *Highest* (whichever limit is closest to running out)
- **Refresh every** — 30s / 60s / 2m / 5m
- **Launch at login**

## How it works & privacy

Everything runs locally. The app gets the real numbers the same way Claude Code does:

1. It reads the OAuth login token Claude Code already stores in your **macOS Keychain**.
2. It calls the same usage endpoint Claude Code's `/usage` uses and reads the limit percentages.
3. If the token is ever expired, it falls back to running `claude -p "/usage"`, which refreshes
   the token and returns the same data.

No servers, no analytics, no accounts. The only network request is the usage check itself,
straight to Anthropic — exactly the one Claude Code already makes. Token counts in the
"Activity today" section are computed from the local log files under `~/.claude/projects`.

Settings are stored in `UserDefaults`; a small activity cache lives in
`~/Library/Application Support/ClaudeUsageBar/`.

## Supported plans

Works on any Claude **subscription** that Claude Code signs into — Pro, Max, Team, Enterprise.
Session and weekly limits show on every plan, and any model-scoped weekly limits are picked up
automatically and labeled by model. Running Claude Code with a raw API key (pay-as-you-go)
instead of a subscription is not supported — that uses a different limit system.

## Limitations

- macOS only.
- It relies on an internal Claude Code usage endpoint. If Anthropic changes it, the app may need
  an update (it will fall back to the CLI in the meantime).
- The "Activity today" token counts are approximate and reflect only sessions on this machine.

## Uninstall

```sh
rm -rf /Applications/ClaudeUsageBar.app
rm -rf ~/Library/Application\ Support/ClaudeUsageBar
```

## Development

```sh
swift build -c release
.build/release/ClaudeUsageBar --dump   # prints your live limits + token activity to the terminal
```

## License

[MIT](LICENSE)

---

*Unofficial. Not affiliated with or endorsed by Anthropic. "Claude" and "Claude Code" are
trademarks of Anthropic.*
