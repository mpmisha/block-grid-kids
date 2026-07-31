# Block Grid Kids — Implementation Plan

A private, ad-free, offline block-puzzle game for a single iPhone.

## 1. Goals & non-goals

### Goals
- Recreate the *general mechanics* of an 8×8 drag-and-drop block puzzle.
- Colorful, playful, kid-friendly presentation.
- One game mode only: classic endless.
- Persistent high score, resettable from a settings menu.
- Installs directly on one personal iPhone from Xcode. No App Store.

### Non-goals (deliberately excluded)
- No ads, no ad SDKs, no rewarded video.
- No in-app purchases, no monetization of any kind.
- No analytics, telemetry, crash reporting, or third-party SDKs.
- No network access at all — the app never makes a request.
- No accounts, no leaderboards, no sharing, no external links.
- No original-game branding, art, audio, or assets (clean-room, original look).

Kid-safety is achieved structurally: the app has zero networking code and zero
third-party dependencies, so there is nothing that *can* show an ad.

## 2. Technology choices

| Concern | Choice | Why |
| --- | --- | --- |
| Language | Swift 5 | Native, no runtime deps |
| Rendering | SpriteKit | Ideal for 2D grid games, drag/drop, particles |
| App shell | SwiftUI (`SpriteView`) | Minimal hosting layer, modern lifecycle |
| Persistence | `UserDefaults` + `Codable` | No DB needed; tiny state |
| Audio | Synthesized WAV in memory (`AVAudioPlayer`) | No audio asset files to license/ship |
| Haptics | `UIFeedbackGenerator` | Native tactile feedback |
| Icon | Generated 1024×1024 PNG | Original artwork, no third-party assets |
| Tests | XCTest on the pure-logic layer | Verifiable without a device |
| Min iOS | 17.0 | Broad device support, modern APIs |
| Orientation | Portrait only | Simpler layout, matches phone play |

### Why the whole UI lives in SpriteKit
Score, tray, buttons, settings panel and game-over panel are all `SKNode`s.
That gives **one coordinate system and one layout pass**, avoiding SwiftUI↔SpriteKit
coordinate mismatches. SwiftUI is only a thin full-screen host.

## 3. Architecture

```
BlockGridKids/
├── App/          SwiftUI entry point + SpriteView host
├── Model/        Pure game logic (Foundation only, unit-testable)
├── Scene/        SpriteKit rendering, layout, input, animation
├── Support/      Theme, audio, haptics, persistence, safe-area
└── Assets.xcassets
```

The `Model` layer has **no** UIKit/SpriteKit imports, so it is fully testable and
can never depend on rendering details.

### Model layer

| Type | Responsibility |
| --- | --- |
| `GridPosition` | `row`/`col` coordinate |
| `Board` | 8×8 cell state (`colorIndex?` per cell), fit checks, clearing |
| `ShapeTemplate` | One block shape: normalized cell offsets + spawn weight |
| `ShapeLibrary` | The catalogue of all shapes |
| `Piece` | A concrete tray piece: template + color + identity |
| `ShapeGenerator` | Weighted random tray sets, biased to stay playable |
| `ScoringEngine` | Placement / line-clear / combo / streak points |
| `GameEngine` | Orchestrates board + tray + score + game-over |
| `GameSnapshot` | `Codable` save state for resume-after-quit |

### Scene layer

| Type | Responsibility |
| --- | --- |
| `GameScene` | Layout, input routing, animation, panels |
| `BlockNode` | One beveled, rounded block cell |
| `PieceNode` | A draggable multi-cell piece |
| `BoardNode` | Grid background + placed blocks + ghost preview |
| `HUDNode` | Score, best score, settings button |
| `PanelNode` | Reusable rounded panel used by settings/game-over |
| `ButtonNode` | Tappable rounded button with press feedback |

## 4. Game rules

1. Board is 8×8, initially empty.
2. The tray holds **3** pieces; the player may place them in any order.
3. Pieces **cannot be rotated** (matches the genre).
4. A piece may be placed only where every one of its cells lands on an
   in-bounds, empty board cell.
5. After placement, every fully-filled row and column clears simultaneously.
6. When all 3 tray pieces are used, a new set of 3 is generated.
7. The game ends when **no** remaining tray piece fits anywhere on the board.

### Scoring

| Event | Points |
| --- | --- |
| Placing a piece | `+1` per cell |
| Clearing lines | `+10 × lines²` (1→10, 2→40, 3→90, 4→160) |
| Streak bonus | `+5 × streak` when a placement clears at least one line |

`streak` increments on every placement that clears something and resets to `0`
on a placement that clears nothing.

### Kid-friendly generation
Pure random tray sets can end a game instantly and unfairly. `ShapeGenerator`
retries a set (up to a bounded number of attempts) until **at least one** piece
in the set fits the current board, then falls back to the smallest shapes.
This dramatically reduces frustrating dead-ends without making the game trivial.

Shape weights favour small/medium pieces; the awkward 3×3 and 5-long bars are
rare.

## 5. Visual design

- **Background** — vertical blue→indigo gradient, plus slow-drifting translucent
  bubbles for a soft playful feel.
- **Board** — dark navy rounded cells with subtle separation.
- **Blocks** — rounded squares with a lighter inner face and a white top-left
  highlight, producing the classic beveled candy look.
- **Palette** — 8 saturated, high-contrast colors (purple, green, orange, blue,
  pink, yellow, cyan, red) chosen to stay distinguishable for young players.
- **Feedback** — pieces pop when lifted, ghost preview shows the landing spot,
  cleared lines flash, scale up and burst into confetti squares, and the score
  label pulses.
- **Typography** — heavy rounded system font, large numbers.

### Layout algorithm
```
cell = min( (width - 32) / 8 , verticalBudget / 9.7 )
board  = 8 × cell, horizontally centered
tray   = 3 slots, each auto-scaling its piece to fit the slot box
```
Safe-area insets come from the key window, with sane fallbacks, so the HUD
clears the Dynamic Island and the tray clears the home indicator.

## 6. UI surfaces

| Surface | Contents |
| --- | --- |
| Playfield | Score, best score, gear button, board, 3-piece tray |
| Settings | Sound toggle, haptics toggle, New game, Reset best score (with confirm), Close |
| Game over | Final score, best score, "New best!" badge, Play again |

No other menus, no title screen — the app opens straight into a playable board.

## 7. Persistence

`UserDefaults` keys:
- `bestScore` — the high score.
- `soundEnabled`, `hapticsEnabled` — settings toggles.
- `savedGame` — JSON `GameSnapshot` so an interrupted game resumes on relaunch.

Resetting the high score from settings clears only `bestScore`.

## 8. iPhone integration

- Portrait-only, full-screen, no status-bar clutter.
- Auto-saves on background/termination so a kid never loses progress.
- Haptics on lift/place/clear/game-over.
- Audio uses the `ambient` session category so it never interrupts music and
  respects the silent switch.
- Generated app icon (1024×1024, single-size modern asset catalog format).
- Generated launch background color matching the in-game gradient.

## 9. Build & install

1. `open BlockGridKids.xcodeproj`
2. Select the personal team, set a unique bundle id.
3. Choose the connected iPhone and press Run.
4. Trust the developer profile on the device.

Full details, including the free-Apple-ID 7-day re-signing caveat, live in
`docs/INSTALL_ON_IPHONE.md`.

## 10. Validation strategy

- `xcodebuild build` against the iOS Simulator SDK to prove it compiles.
- `xcodebuild test` running the XCTest logic suite covering board fitting,
  clearing, scoring, game-over detection and save/restore round-trips.
- Manual on-device play-test is the final acceptance step.

## 11. Legal position

Only *mechanics* are reproduced, which are not protected the way expression is.
No name, icon, artwork, audio, code or asset from any existing product is used.
The app is private, unpublished, and installed on one personal device.
