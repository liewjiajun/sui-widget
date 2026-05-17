# Sui Widget

A free, native iOS app that displays a Sui user's portfolio, NFTs, staking positions, and ecosystem news on Home Screen and Lock Screen widgets. See [`CLAUDE.md`](CLAUDE.md) for the full technical brief.

## Prerequisites

- macOS with Xcode 16+ installed
- Homebrew
- `brew install xcodegen`

## Bootstrap

```bash
xcodegen generate                # produces SuiWidget.xcodeproj from project.yml
open SuiWidget.xcodeproj         # then pick a Development Team on both targets
```

## Run the Phase 0 acceptance test

1. Build & run the **SuiWidget** scheme on an iPhone simulator.
2. The app shows the value it just wrote to the `group.io.sui.widget` App Group container.
3. Add the **Sui Handshake** widget to the simulator's Home Screen (long-press, +, search "Sui").
4. Tap **Write again** in the app; the widget timeline reloads and displays the new value.

## Run the package tests

```bash
swift test --package-path Packages/SuiWidgetKit
```

## Repo layout

See [`docs/superpowers/specs/2026-05-17-phase-0-project-setup-design.md`](docs/superpowers/specs/2026-05-17-phase-0-project-setup-design.md) for the authoritative design.
