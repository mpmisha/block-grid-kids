# Block Grid — Web (PWA) version

A faithful web port of the Block Grid iPhone game, built so you can put it on a
kid's iPhone **for free** — no $99/year Apple Developer account, no 7-day
side-loading expiry. You just open a link once and **Add to Home Screen**.

It's the same game: the 8×8 (or 5×5) block-drop puzzle, the same shapes,
scoring, line-clear celebrations, perfect-clear level-ups with 256 looks, and
the same synthesized sounds — all rendered on an HTML `<canvas>`, no ads, no
accounts, no tracking. Once installed it works fully **offline**.

## Try it locally

Any static file server works (a service worker requires `http://localhost` or
HTTPS — opening the file directly won't register offline support):

```bash
cd web
python3 -m http.server 8137
# then open http://localhost:8137 in a browser
```

## Put it on an iPhone (free, no App Store)

1. **Host the `web/` folder somewhere with HTTPS.** The easiest free option is
   **GitHub Pages**:
   - Push this repo to GitHub.
   - In the repo: **Settings → Pages → Build and deployment → Deploy from a
     branch**, pick your branch and set the folder to `/web` (or move `web/`'s
     contents to a `docs/` folder and select `/docs`).
   - GitHub gives you a URL like `https://<you>.github.io/<repo>/`.
2. On the iPhone, open that URL in **Safari**.
3. Tap the **Share** button → **Add to Home Screen** → **Add**.
4. Launch it from the new home-screen icon. It opens fullscreen (no Safari
   chrome) and runs offline from then on.

> iOS note: audio only starts after the first tap (a browser rule), and the
> game unlocks sound on the first touch automatically. Best scores and the
> in-progress game are saved in the browser's local storage.

## What's inside

```
web/
  index.html              App shell + HUD/settings/game-over overlays (DOM)
  styles.css              Overlay + HUD styling
  manifest.webmanifest    PWA metadata (installable, standalone, portrait)
  service-worker.js       Caches everything for offline play
  icons/                  App icons (generated from the iOS app icon)
  js/
    shapes.js    Shape templates + library      (port of ShapeTemplate.swift)
    board.js     Board rules                     (port of Board.swift)
    scoring.js   Scoring rules                   (port of ScoringEngine.swift)
    generator.js Tray generation                 (port of ShapeGenerator.swift)
    skins.js     Skin selection + palettes       (port of SkinSelection/Skin.swift)
    color.js     Color math (HSB brightness, lighten)
    engine.js    Game engine + best-score store  (port of GameEngine.swift)
    textures.js  Canvas block/cell/background textures (port of the SpriteKit caches)
    audio.js     Web Audio tone synth + haptics  (port of SoundPlayer.swift)
    storage.js   Settings + saved-game (localStorage)
    scene.js     Canvas renderer, input, effects, game loop (port of GameScene.swift)
    main.js      Wires the DOM overlays to the scene
```

The game rules (`shapes`, `board`, `scoring`, `generator`, `skins`, `engine`)
are a 1:1 port of the Swift model and are verified against it — same shape
weights, same `10 × lines²` line scoring, same `5 × (streak-1)` streak bonus,
same perfect-clear/level logic, same 256-look skin system.
