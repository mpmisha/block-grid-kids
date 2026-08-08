// The single scene that renders and drives the whole game.
// Canvas port of Scene/GameScene.swift (+ BoardNode, PieceNode, Effects).
import { GameEngine } from './engine.js';
import { GameConfiguration } from './generator.js';
import { SkinCatalog } from './skins.js';
import { css, adjustBrightness, lightened } from './color.js';
import { BlockTextureCache, makeBackgroundCanvas, roundRect } from './textures.js';
import { SoundPlayer, Haptics } from './audio.js';
import { SettingsStore, GameStateStore } from './storage.js';

const BLOCK_CORNER_RADIUS_RATIO = 0.16;
const CROWN_GOLD = 'rgba(255, 204, 61, 1)';
const GAME_OVER_BLOCK = { r: 0.36, g: 0.38, b: 0.50, a: 1 };

const HUD_HEIGHT = 76;
const GAP_TOP = 10;
const GAP_BOARD_TRAY = 18;
const GAP_BOTTOM = 8;
const H_PADDING = 16;
const TRAY_ROW_UNITS = 3;

const clamp01 = (x) => Math.max(0, Math.min(1, x));
const lerp = (a, b, t) => a + (b - a) * clamp01(t);
// easeOutBack for lively pops.
function easeOutBack(t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
}

export class GameScene {
  constructor(canvas, dom) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.dom = dom; // { hudScore, hudBest, gear, settingsBtn, ... } wired in main

    this.settings = SettingsStore;
    this.sound = new SoundPlayer(this.settings);
    this.haptics = new Haptics(this.settings);
    this.textures = new BlockTextureCache();

    this.engine = new GameEngine(this.settings.boardSize);

    this.dpr = Math.min(window.devicePixelRatio || 1, 3);
    this.width = 0;
    this.height = 0;
    this.insets = { top: 24, bottom: 14 };

    this.cellSide = 40;
    this.boardX = 0;
    this.boardY = 0;
    this.boardSide = 0;
    this.traySlotCenters = [];
    this.traySlot = { w: 0, h: 0 };

    this.backgroundCanvas = null;
    this.effects = [];
    this.cellAnim = new Map(); // "row,col" -> { start, delay }
    this.gameOverSweep = null; // { start }
    this.drag = null;
    this.overlayOpen = false;

    // Restore a saved game if possible, then adopt its skin.
    this.restoreSavedGameIfPossible();
    SkinCatalog.apply(this.engine.skin);
    this.textures.invalidateForSkinChange();

    this.bindEvents();
    this.resize();
    this.updateHud(false);
    this.loop = this.loop.bind(this);
    requestAnimationFrame(this.loop);

    if (this.engine.isGameOver) this.presentGameOver(false, false);
  }

  // MARK: - Insets

  measureInsets() {
    const probe = document.getElementById('safe-probe');
    if (!probe) return;
    const s = getComputedStyle(probe);
    const top = parseFloat(s.paddingTop) || 0;
    const bottom = parseFloat(s.paddingBottom) || 0;
    this.insets = { top: Math.max(top, 24), bottom: Math.max(bottom, 14) };
  }

  // MARK: - Layout

  resize() {
    this.measureInsets();
    const w = window.innerWidth;
    const h = window.innerHeight;
    this.width = w;
    this.height = h;
    this.dpr = Math.min(window.devicePixelRatio || 1, 3);
    this.canvas.width = Math.round(w * this.dpr);
    this.canvas.height = Math.round(h * this.dpr);
    this.canvas.style.width = `${w}px`;
    this.canvas.style.height = `${h}px`;
    this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);

    this.performLayout();
    this.backgroundCanvas = makeBackgroundCanvas(w, h);
    this.positionHud();
  }

  performLayout() {
    const size = this.engine.board.size;
    const boardMaxWidth = this.width - H_PADDING * 2;
    const verticalBudget = this.height - this.insets.top - this.insets.bottom
      - HUD_HEIGHT - GAP_TOP - GAP_BOARD_TRAY - GAP_BOTTOM;

    this.cellSide = Math.max(18, Math.min(
      boardMaxWidth / size,
      verticalBudget / (size + TRAY_ROW_UNITS),
    ));
    this.boardSide = this.cellSide * size;
    const trayHeight = this.cellSide * TRAY_ROW_UNITS;
    this.textures.prepare(this.cellSide);

    const contentTop = this.insets.top + HUD_HEIGHT + GAP_TOP;
    const contentBottom = this.height - this.insets.bottom - GAP_BOTTOM;
    const contentHeight = contentBottom - contentTop;
    const usedHeight = this.boardSide + GAP_BOARD_TRAY + trayHeight;
    const extra = Math.max(0, contentHeight - usedHeight);

    this.boardX = (this.width - this.boardSide) / 2;
    this.boardY = contentTop + extra / 2;

    const trayCenterY = this.boardY + this.boardSide + GAP_BOARD_TRAY + trayHeight / 2;
    this.traySlot = { w: this.width / GameConfiguration.traySize - 10, h: trayHeight };
    const step = this.width / GameConfiguration.traySize;
    this.traySlotCenters = [];
    for (let i = 0; i < GameConfiguration.traySize; i++) {
      this.traySlotCenters.push({ x: step * (i + 0.5), y: trayCenterY });
    }
  }

  positionHud() {
    const header = this.dom.header;
    header.style.top = `${this.insets.top}px`;
    header.style.height = `${HUD_HEIGHT}px`;
  }

  // MARK: - Geometry helpers

  cellCenter(row, col) {
    return {
      x: this.boardX + (col + 0.5) * this.cellSide,
      y: this.boardY + (row + 0.5) * this.cellSide,
    };
  }

  nearestOrigin(topLeftX, topLeftY) {
    const col = Math.round((topLeftX - this.boardX) / this.cellSide - 0.5);
    const row = Math.round((topLeftY - this.boardY) / this.cellSide - 0.5);
    return { row, col };
  }

  trayPieceMetrics(piece) {
    const cols = piece.shape.width;
    const rows = piece.shape.height;
    const contentW = cols * this.cellSide;
    const contentH = rows * this.cellSide;
    const maxW = this.traySlot.w * 0.86;
    const maxH = this.traySlot.h * 0.86;
    const scale = Math.min(0.75, Math.min(maxW / Math.max(1, contentW), maxH / Math.max(1, contentH)));
    return { cols, rows, contentW, contentH, scale };
  }

  traySlotRect(index) {
    const c = this.traySlotCenters[index];
    return {
      x: c.x - this.traySlot.w / 2, y: c.y - this.traySlot.h / 2,
      w: this.traySlot.w, h: this.traySlot.h,
    };
  }

  // MARK: - Input

  bindEvents() {
    window.addEventListener('resize', () => this.resize());
    window.addEventListener('orientationchange', () => setTimeout(() => this.resize(), 200));

    const opts = { passive: false };
    this.canvas.addEventListener('pointerdown', (e) => this.onPointerDown(e), opts);
    this.canvas.addEventListener('pointermove', (e) => this.onPointerMove(e), opts);
    this.canvas.addEventListener('pointerup', (e) => this.onPointerUp(e), opts);
    this.canvas.addEventListener('pointercancel', () => this.cancelDrag());

    window.addEventListener('pagehide', () => this.saveGameState());
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden') this.saveGameState();
    });
  }

  pointFromEvent(e) {
    const rect = this.canvas.getBoundingClientRect();
    return { x: e.clientX - rect.left, y: e.clientY - rect.top };
  }

  onPointerDown(e) {
    if (this.overlayOpen || this.engine.isGameOver) return;
    this.sound.unlock();
    const p = this.pointFromEvent(e);
    for (let i = 0; i < GameConfiguration.traySize; i++) {
      if (!this.engine.piece(i)) continue;
      const r = this.traySlotRect(i);
      if (p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h) {
        this.canvas.setPointerCapture(e.pointerId);
        this.beginDrag(i, p);
        e.preventDefault();
        return;
      }
    }
  }

  onPointerMove(e) {
    if (!this.drag) return;
    e.preventDefault();
    this.updateDrag(this.pointFromEvent(e));
  }

  onPointerUp(e) {
    if (!this.drag) return;
    e.preventDefault();
    this.finishDrag(this.pointFromEvent(e));
  }

  beginDrag(index, p) {
    const piece = this.engine.piece(index);
    this.drag = {
      index, piece, pointer: p, validOrigin: null,
      previewClear: false, pickStart: performance.now() / 1000,
    };
    this.updateDrag(p);
    this.haptics.pickUp();
    this.sound.play('pickUp');
  }

  updateDrag(p) {
    const d = this.drag;
    d.pointer = p;
    const { cols, rows } = this.trayPieceMetrics(d.piece);
    const lift = (rows * this.cellSide) / 2 + this.cellSide * 0.95;
    const bboxCX = p.x;
    const bboxCY = p.y - lift;
    const topLeftX = bboxCX - ((cols - 1) / 2) * this.cellSide;
    const topLeftY = bboxCY - ((rows - 1) / 2) * this.cellSide;
    const origin = this.nearestOrigin(topLeftX, topLeftY);

    if (this.engine.canPlace(d.index, origin)) {
      d.validOrigin = origin;
      const lines = this.engine.linesCompleted(d.index, origin);
      const willClear = lines.rows.length > 0 || lines.columns.length > 0;
      d.clearHint = lines;
      if (willClear && !d.previewClear) this.haptics.pickUp();
      d.previewClear = willClear;
    } else {
      d.validOrigin = null;
      d.previewClear = false;
      d.clearHint = null;
    }
  }

  finishDrag(p) {
    const d = this.drag;
    if (!d) return;
    if (d.validOrigin) {
      this.drag = null;
      this.place(d.index, d.validOrigin, d.piece);
    } else {
      this.drag = null;
      this.haptics.invalid();
      this.sound.play('invalid');
    }
  }

  cancelDrag() {
    this.drag = null;
  }

  // MARK: - Placement

  place(index, origin, piece) {
    const before = this.engine.board.cells.slice();
    const size = this.engine.board.size;
    const result = this.engine.place(index, origin);
    if (!result) return;

    // Landing bounce for each placed cell.
    const now = performance.now() / 1000;
    result.placedPositions.forEach((pos, i) => {
      this.cellAnim.set(`${pos.row},${pos.col}`, { start: now, delay: i * 0.015 });
    });

    this.haptics.place();
    this.sound.play('place');
    this.updateHud(true);
    if (result.isNewBestScore) this.celebrateNewBest();

    // Floating score above the board.
    if (result.breakdown.total > 0) {
      this.floatingScore(result.breakdown.total,
        this.boardX + this.boardSide / 2, this.boardY - 26,
        result.didClearLines ? CROWN_GOLD : 'white');
    }

    if (result.didClearLines) {
      // Resolve the color at each cleared cell (placed cells use the new color).
      const placedKeys = new Set(result.placedPositions.map((q) => `${q.row},${q.col}`));
      this.animateClears(result, before, size, placedKeys, piece.colorIndex);
    }

    if (result.isPerfectClear) this.celebratePerfectClear(result.level);

    if (result.isGameOver) {
      const delay = result.didClearLines ? 0.85 : 0.55;
      setTimeout(() => this.presentGameOver(result.isNewBestScore, true), delay * 1000);
    }

    this.saveGameState();
  }

  animateClears(result, before, size, placedKeys, placedColor) {
    this.haptics.clearLines();
    this.sound.play(result.clearedLineCount > 1 ? 'clearCombo' : 'clearSingle');
    this.flashLines(result.clearedRows, result.clearedColumns);

    const now = performance.now() / 1000;
    result.clearedPositions.forEach((pos, index) => {
      const delay = (pos.col + pos.row) * 0.012;
      const key = `${pos.row},${pos.col}`;
      const colorIndex = placedKeys.has(key) ? placedColor : before[pos.row * size + pos.col];
      if (colorIndex === null || colorIndex === undefined) return;
      const c = this.cellCenter(pos.row, pos.col);
      this.clearingBlock(c.x, c.y, colorIndex, now + delay);
      if (index % 3 === 0) this.confettiBurst(c.x, c.y, colorIndex, now + delay + 0.1);
    });

    const praise = this.praiseText(result.clearedLineCount, result.streak);
    if (praise) this.praise(praise, this.width / 2, this.boardY + this.boardSide / 2);
  }

  praiseText(lineCount, streak) {
    if (lineCount >= 4) return 'AMAZING!';
    if (lineCount === 3) return 'SUPER!';
    if (lineCount === 2) return 'GREAT!';
    if (streak >= 5) return 'ON FIRE!';
    if (streak >= 3) return 'NICE!';
    return null;
  }

  celebratePerfectClear(level) {
    setTimeout(() => {
      this.haptics.clearLines();
      this.sound.play('levelUp');
      this.perfectCelebration(this.boardX + this.boardSide / 2, this.boardY + this.boardSide / 2, this.boardSide, level);
      this.skinChangeFlash(() => this.applySkin(this.engine.skin));
    }, 340);
  }

  applySkin(selection) {
    if (!SkinCatalog.apply(selection)) return;
    this.textures.invalidateForSkinChange();
    this.backgroundCanvas = makeBackgroundCanvas(this.width, this.height);
  }

  // MARK: - HUD + overlays (delegated to DOM via callbacks set in main)

  updateHud(animated) {
    this.dom.hudScore.textContent = String(this.engine.score);
    this.dom.hudBest.textContent = String(this.engine.visibleBestScore);
    if (animated) {
      const el = this.dom.hudScore;
      el.classList.remove('pulse');
      void el.offsetWidth;
      el.classList.add('pulse');
    }
  }

  celebrateNewBest() {
    this.dom.hudBest.textContent = String(this.engine.bestScore);
    this.dom.bestBadge.classList.remove('celebrate');
    void this.dom.bestBadge.offsetWidth;
    this.dom.bestBadge.classList.add('celebrate');
  }

  presentSettings() {
    if (this.overlayOpen) return;
    this.cancelDrag();
    this.overlayOpen = true;
    this.dom.onPresentSettings();
  }

  presentGameOver(isNewBest, animateBoard) {
    if (this.overlayOpen) return;
    this.haptics.gameOver();
    this.sound.play('gameOver');
    GameStateStore.clear();

    const showPanel = () => {
      if (this.overlayOpen) return;
      this.overlayOpen = true;
      this.dom.onPresentGameOver({
        score: this.engine.score,
        bestScore: this.engine.bestScore,
        isNewBest,
      });
    };

    if (!animateBoard) { showPanel(); return; }
    this.praise('No Moves Left', this.width / 2, this.boardY + this.boardSide / 2);
    this.gameOverSweep = { start: performance.now() / 1000, onDone: showPanel, fired: false };
  }

  dismissOverlay() {
    this.overlayOpen = false;
  }

  startNewGame() {
    this.engine.startNewGame();
    GameStateStore.clear();
    this.applySkin(this.engine.skin);
    this.gameOverSweep = null;
    this.cellAnim.clear();
    this.effects = [];
    this.updateHud(false);
  }

  changeBoardSize(newSize) {
    if (!this.engine.changeBoardSize(newSize)) return;
    this.settings.boardSize = newSize;
    GameStateStore.clear();
    this.applySkin(this.engine.skin);
    this.gameOverSweep = null;
    this.cellAnim.clear();
    this.effects = [];
    this.performLayout();
    this.updateHud(false);
  }

  resetBestScore() {
    this.engine.resetBestScore();
    this.updateHud(false);
  }

  // MARK: - Persistence

  restoreSavedGameIfPossible() {
    const snapshot = GameStateStore.loadSnapshot();
    if (snapshot) this.engine.restore(snapshot);
  }

  saveGameState() {
    if (this.engine.isGameOver) { GameStateStore.clear(); return; }
    GameStateStore.save(this.engine.makeSnapshot());
  }

  // MARK: - Effects

  floatingScore(amount, x, y, color) {
    const start = performance.now() / 1000;
    this.effects.push((ctx, now) => {
      const t = now - start;
      const total = 0.71;
      if (t > total) return false;
      let scale, dy, alpha;
      if (t < 0.16) {
        const p = t / 0.16;
        scale = lerp(0.6, 1.15, p); dy = lerp(0, 26, p); alpha = 1;
      } else {
        const p = (t - 0.16) / 0.55;
        scale = lerp(1.15, 0.9, p); dy = lerp(26, 70, p); alpha = 1 - p;
      }
      ctx.save();
      ctx.globalAlpha = alpha;
      ctx.fillStyle = color;
      ctx.font = `900 ${30 * scale}px "Baloo 2", system-ui, sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(`+${amount}`, x, y - dy);
      ctx.restore();
      return true;
    });
  }

  praise(text, x, y) {
    const start = performance.now() / 1000;
    this.effects.push((ctx, now) => {
      const t = now - start;
      const total = 1.14;
      if (t > total) return false;
      let scale = 1, alpha = 1, dy = 0;
      if (t < 0.14) { alpha = t / 0.14; scale = lerp(0.3, 1.12, t / 0.18); }
      else if (t < 0.24) { scale = lerp(1.12, 1.0, (t - 0.14) / 0.1); }
      else if (t < 0.66) { scale = 1; }
      else { const p = (t - 0.66) / 0.3; alpha = 1 - p; dy = lerp(0, 30, p); }
      ctx.save();
      ctx.globalAlpha = clamp01(alpha);
      ctx.fillStyle = CROWN_GOLD;
      ctx.font = `900 ${34 * scale}px "Baloo 2", system-ui, sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(text, x, y - dy);
      ctx.restore();
      return true;
    });
  }

  flashLines(rows, columns) {
    const positions = new Set();
    const size = this.engine.board.size;
    for (const row of rows) for (let c = 0; c < size; c++) positions.add(`${row},${c}`);
    for (const col of columns) for (let r = 0; r < size; r++) positions.add(`${r},${col}`);
    const start = performance.now() / 1000;
    const radius = this.cellSide * BLOCK_CORNER_RADIUS_RATIO;
    const cells = [...positions].map((k) => k.split(',').map(Number));
    this.effects.push((ctx, now) => {
      const t = now - start;
      if (t > 0.28) return false;
      const alpha = (1 - t / 0.28) * 0.85;
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';
      ctx.globalAlpha = alpha;
      ctx.fillStyle = 'white';
      for (const [row, col] of cells) {
        const c = this.cellCenter(row, col);
        roundRect(ctx, c.x - this.cellSide / 2, c.y - this.cellSide / 2, this.cellSide, this.cellSide, radius);
        ctx.fill();
      }
      ctx.restore();
      return true;
    });
  }

  clearingBlock(x, y, colorIndex, startTime) {
    const tex = this.textures.filledTexture(colorIndex);
    const side = this.cellSide;
    this.effects.push((ctx, now) => {
      const t = now - startTime;
      if (t < 0) return true;
      const total = 0.28;
      if (t > total) return false;
      let scale, alpha, rot;
      if (t < 0.12) { const p = t / 0.12; scale = lerp(1, 1.35, p); alpha = lerp(1, 0.9, p); rot = 0; }
      else { const p = (t - 0.12) / 0.16; scale = lerp(1.35, 0.05, p); alpha = lerp(0.9, 0, p); rot = lerp(0, Math.PI / 5, p); }
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(rot);
      ctx.scale(scale, scale);
      ctx.globalAlpha = clamp01(alpha);
      ctx.drawImage(tex, -side / 2, -side / 2, side, side);
      ctx.restore();
      return true;
    });
  }

  confettiBurst(x, y, colorIndex, startTime) {
    const baseColor = SkinCatalog.blockPalette.colors[((colorIndex % 8) + 8) % 8];
    const cell = this.cellSide;
    for (let i = 0; i < 5; i++) {
      const side = cell * (0.14 + Math.random() * 0.12);
      const angle = Math.random() * Math.PI * 2;
      const distance = cell * (0.7 + Math.random() * 1.2);
      const dx = Math.cos(angle) * distance;
      const dy = Math.sin(angle) * distance;
      const duration = 0.35 + Math.random() * 0.25;
      const spin = (Math.random() - 0.5) * 6;
      const color = css(lightened(baseColor, Math.random() * 0.4));
      this.effects.push((ctx, now) => {
        const t = now - startTime;
        if (t < 0) return true;
        if (t > duration) return false;
        const p = t / duration;
        const alpha = p < 0.45 ? 1 : 1 - (p - 0.45) / 0.55;
        const s = lerp(1, 0.3, p);
        ctx.save();
        ctx.globalAlpha = clamp01(alpha);
        ctx.translate(x + dx * p, y + dy * p);
        ctx.rotate(spin * p);
        ctx.fillStyle = color;
        ctx.fillRect((-side * s) / 2, (-side * s) / 2, side * s, side * s);
        ctx.restore();
        return true;
      });
    }
  }

  perfectCelebration(cx, cy, boardSide, level) {
    const now = performance.now() / 1000;

    // Expanding rings.
    for (let i = 0; i < 3; i++) {
      const startTime = now + i * 0.14;
      const baseR = boardSide * 0.16;
      this.effects.push((ctx, t2) => {
        const t = t2 - startTime;
        if (t < 0) return true;
        const total = 0.68;
        if (t > total) return false;
        const p = t / total;
        const alpha = p < 0.1 ? p / 0.1 * 0.9 : 0.9 * (1 - (p - 0.1) / 0.9);
        ctx.save();
        ctx.globalCompositeOperation = 'lighter';
        ctx.globalAlpha = clamp01(alpha);
        ctx.strokeStyle = CROWN_GOLD;
        ctx.lineWidth = Math.max(3, boardSide * 0.016);
        ctx.beginPath();
        ctx.arc(cx, cy, baseR * lerp(1, 3.2, p), 0, Math.PI * 2);
        ctx.stroke();
        ctx.restore();
        return true;
      });
    }

    // Confetti fountain rising from the board bottom.
    const colors = SkinCatalog.blockPalette.colors;
    for (let i = 0; i < 26; i++) {
      const side = boardSide * (0.02 + Math.random() * 0.02);
      const h = side * (0.7 + Math.random() * 0.8);
      const color = css(colors[i % colors.length]);
      const px = cx + (Math.random() - 0.5) * boardSide;
      const py = cy + boardSide * 0.45;
      const rise = boardSide * (0.55 + Math.random() * 0.5);
      const drift = (Math.random() - 0.5) * boardSide * 0.36;
      const duration = 0.7 + Math.random() * 0.45;
      const startTime = now + i * 0.012;
      const spin = (Math.random() - 0.5) * 12;
      this.effects.push((ctx, t2) => {
        const t = t2 - startTime;
        if (t < 0) return true;
        if (t > duration) return false;
        const p = t / duration;
        let yOff, xOff;
        if (p < 0.55) { const q = p / 0.55; yOff = -rise * q; xOff = drift * q; }
        else { const q = (p - 0.55) / 0.45; yOff = -rise + rise * 0.35 * q; xOff = drift + drift * 0.4 * q; }
        const alpha = p < 0.55 ? 1 : 1 - (p - 0.55) / 0.45;
        ctx.save();
        ctx.globalAlpha = clamp01(alpha);
        ctx.translate(px + xOff, py + yOff);
        ctx.rotate(spin * p);
        ctx.fillStyle = color;
        ctx.fillRect(-side / 2, -h / 2, side, h);
        ctx.restore();
        return true;
      });
    }

    // PERFECT! banner naming the new level.
    const bannerStart = now;
    this.effects.push((ctx, t2) => {
      const t = t2 - bannerStart;
      const total = 1.6;
      if (t > total) return false;
      let scale = 1, alpha = 1, dy = 0;
      if (t < 0.16) { alpha = t / 0.16; scale = lerp(0.3, 1.0, t / 0.38); }
      else if (t < 0.38) { scale = lerp(1.0, 1.18, (t - 0.16) / 0.22); }
      else if (t < 0.5) { scale = lerp(1.18, 1.0, (t - 0.38) / 0.12); }
      else if (t < 1.26) { scale = 1; }
      else { const p = (t - 1.26) / 0.34; alpha = 1 - p; dy = lerp(0, 34, p); scale = lerp(1, 0.9, p); }
      ctx.save();
      ctx.globalAlpha = clamp01(alpha);
      ctx.translate(cx, cy - dy);
      ctx.scale(scale, scale);
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillStyle = CROWN_GOLD;
      ctx.font = '900 46px "Baloo 2", system-ui, sans-serif';
      ctx.fillText('PERFECT!', 0, -16);
      ctx.fillStyle = 'white';
      ctx.font = '800 26px "Baloo 2", system-ui, sans-serif';
      ctx.fillText(`LEVEL ${level}`, 0, 22);
      ctx.restore();
      return true;
    });
  }

  skinChangeFlash(onPeak) {
    const start = performance.now() / 1000;
    let fired = false;
    this.effects.push((ctx, now) => {
      const t = now - start;
      const total = 0.58;
      if (t > total) return false;
      let alpha;
      if (t < 0.16) alpha = (t / 0.16) * 0.55;
      else {
        if (!fired) { fired = true; onPeak(); }
        alpha = 0.55 * (1 - (t - 0.16) / 0.42);
      }
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';
      ctx.globalAlpha = clamp01(alpha);
      ctx.fillStyle = 'white';
      ctx.fillRect(0, 0, this.width, this.height);
      ctx.restore();
      return true;
    });
  }

  // MARK: - Render loop

  loop(ts) {
    const now = ts / 1000;
    const ctx = this.ctx;
    ctx.clearRect(0, 0, this.width, this.height);

    if (this.backgroundCanvas) {
      ctx.drawImage(this.backgroundCanvas, 0, 0, this.width, this.height);
    }

    this.drawBoard(ctx, now);
    this.drawGhostAndHint(ctx, now);
    this.drawBlocks(ctx, now);
    this.drawTray(ctx, now);
    this.drawDrag(ctx, now);
    this.drawEffects(ctx, now);
    this.tickGameOverSweep(now);

    requestAnimationFrame(this.loop);
  }

  drawBoard(ctx, now) {
    const side = this.boardSide;
    const padding = this.cellSide * 0.14;
    const surface = SkinCatalog.surfacePalette;
    ctx.save();
    ctx.fillStyle = css(surface.boardBackground);
    ctx.strokeStyle = 'rgba(255,255,255,0.10)';
    ctx.lineWidth = 2;
    roundRect(ctx, this.boardX - padding, this.boardY - padding,
      side + padding * 2, side + padding * 2, this.cellSide * 0.35);
    ctx.fill();
    ctx.stroke();
    ctx.restore();

    const emptyTex = this.textures.emptyTexture();
    const size = this.engine.board.size;
    for (let row = 0; row < size; row++) {
      for (let col = 0; col < size; col++) {
        const c = this.cellCenter(row, col);
        ctx.drawImage(emptyTex, c.x - this.cellSide / 2, c.y - this.cellSide / 2, this.cellSide, this.cellSide);
      }
    }
  }

  drawBlocks(ctx, now) {
    const board = this.engine.board;
    const size = board.size;
    const side = this.cellSide;
    const sweep = this.gameOverSweep;

    for (let row = 0; row < size; row++) {
      for (let col = 0; col < size; col++) {
        const colorIndex = board.cells[row * size + col];
        if (colorIndex === null || colorIndex === undefined) continue;
        const tex = this.textures.filledTexture(colorIndex);
        const c = this.cellCenter(row, col);

        let scale = 1;
        let alpha = 1;
        let sag = 0;
        let grey = 0;

        const anim = this.cellAnim.get(`${row},${col}`);
        if (anim) {
          const t = now - anim.start - anim.delay;
          if (t < 0) { scale = 0.72; alpha = 0.85; }
          else if (t < 0.08) { const p = t / 0.08; alpha = lerp(0.85, 1, p); scale = lerp(0.72, 0.86, p); }
          else if (t < 0.17) { scale = lerp(0.86, 1.08, (t - 0.08) / 0.09); }
          else if (t < 0.24) { scale = lerp(1.08, 1.0, (t - 0.17) / 0.07); }
          else { this.cellAnim.delete(`${row},${col}`); }
        }

        if (sweep) {
          const delay = (row + col) * 0.035;
          const t = now - sweep.start - delay;
          if (t > 0) {
            const p = clamp01(t / 0.26);
            grey = p * 0.92;
            alpha *= lerp(1, 0.55, p);
            sag = side * 0.08 * p;
            scale *= t < 0.10 ? lerp(1, 1.12, t / 0.10) : lerp(1.12, 0.88, clamp01((t - 0.10) / 0.16));
          }
        }

        ctx.save();
        ctx.translate(c.x, c.y + sag);
        ctx.scale(scale, scale);
        ctx.globalAlpha = alpha;
        ctx.drawImage(tex, -side / 2, -side / 2, side, side);
        if (grey > 0) {
          ctx.globalAlpha = alpha * grey;
          ctx.fillStyle = css(GAME_OVER_BLOCK);
          roundRect(ctx, -side / 2 + side * 0.013, -side / 2 + side * 0.013,
            side * 0.974, side * 0.974, side * BLOCK_CORNER_RADIUS_RATIO);
          ctx.fill();
        }
        ctx.restore();
      }
    }
  }

  drawGhostAndHint(ctx, now) {
    const d = this.drag;
    if (!d || !d.validOrigin) return;
    const side = this.cellSide;
    const radius = side * BLOCK_CORNER_RADIUS_RATIO;

    // Clear-hint gold cells (pulsing), drawn under the ghost.
    if (d.clearHint && (d.clearHint.rows.length || d.clearHint.columns.length)) {
      const size = this.engine.board.size;
      const positions = new Set();
      for (const row of d.clearHint.rows) for (let c = 0; c < size; c++) positions.add(`${row},${c}`);
      for (const col of d.clearHint.columns) for (let r = 0; r < size; r++) positions.add(`${r},${col}`);
      const pulse = 0.55 + 0.45 * (0.5 + 0.5 * Math.sin(now * Math.PI / 0.34));
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';
      ctx.globalAlpha = pulse;
      for (const k of positions) {
        const [row, col] = k.split(',').map(Number);
        const c = this.cellCenter(row, col);
        const w = side * 0.97;
        ctx.fillStyle = 'rgba(255,204,61,0.24)';
        ctx.strokeStyle = 'rgba(255,204,61,0.85)';
        ctx.lineWidth = Math.max(1.5, side * 0.05);
        roundRect(ctx, c.x - w / 2, c.y - w / 2, w, w, radius);
        ctx.fill();
        ctx.stroke();
      }
      ctx.restore();
    }

    // Translucent ghost of where the piece lands.
    const colors = SkinCatalog.blockPalette.colors;
    const color = colors[((d.piece.colorIndex % 8) + 8) % 8];
    const positions = this.engine.board.positions(d.piece.shape, d.validOrigin);
    ctx.save();
    for (const pos of positions) {
      const c = this.cellCenter(pos.row, pos.col);
      const w = side * 0.86;
      ctx.fillStyle = css({ ...color, a: 0.38 });
      ctx.strokeStyle = css({ ...lightened(color, 0.45), a: 0.85 });
      ctx.lineWidth = Math.max(2, side * 0.05);
      roundRect(ctx, c.x - w / 2, c.y - w / 2, w, w, radius);
      ctx.fill();
      ctx.stroke();
    }
    ctx.restore();
  }

  drawTray(ctx, now) {
    for (let i = 0; i < GameConfiguration.traySize; i++) {
      if (this.drag && this.drag.index === i) continue;
      const piece = this.engine.piece(i);
      if (!piece) continue;
      const m = this.trayPieceMetrics(piece);
      const center = this.traySlotCenters[i];
      const scaledSide = this.cellSide * m.scale;
      // Center the piece bounding box in the slot.
      const originX = center.x - (m.cols * scaledSide) / 2;
      const originY = center.y - (m.rows * scaledSide) / 2;
      for (const off of piece.shape.offsets) {
        const tex = this.textures.filledTexture(piece.colorIndex);
        const x = originX + off.col * scaledSide;
        const y = originY + off.row * scaledSide;
        ctx.drawImage(tex, x, y, scaledSide, scaledSide);
      }
    }
  }

  drawDrag(ctx, now) {
    const d = this.drag;
    if (!d) return;
    const side = this.cellSide;
    const { cols, rows } = this.trayPieceMetrics(d.piece);
    const lift = (rows * side) / 2 + side * 0.95;
    const bboxCX = d.pointer.x;
    const bboxCY = d.pointer.y - lift;
    const topLeftX = bboxCX - ((cols - 1) / 2) * side;
    const topLeftY = bboxCY - ((rows - 1) / 2) * side;

    // Small pick-up pop.
    const t = now - d.pickStart;
    let s = 1;
    if (t < 0.07) s = lerp(1, 1.1, t / 0.07);
    else if (t < 0.13) s = lerp(1.1, 1, (t - 0.07) / 0.06);

    const tex = this.textures.filledTexture(d.piece.colorIndex);
    ctx.save();
    ctx.translate(bboxCX, bboxCY);
    ctx.scale(s, s);
    ctx.translate(-bboxCX, -bboxCY);
    for (const off of d.piece.shape.offsets) {
      const cx = topLeftX + off.col * side;
      const cy = topLeftY + off.row * side;
      ctx.drawImage(tex, cx - side / 2, cy - side / 2, side, side);
    }
    ctx.restore();
  }

  drawEffects(ctx, now) {
    if (this.effects.length === 0) return;
    this.effects = this.effects.filter((fx) => fx(ctx, now));
  }

  tickGameOverSweep(now) {
    const sweep = this.gameOverSweep;
    if (!sweep || sweep.fired) return;
    const size = this.engine.board.size;
    const longest = (size - 1 + size - 1) * 0.035;
    if (now - sweep.start > longest + 0.42) {
      sweep.fired = true;
      const done = sweep.onDone;
      this.gameOverSweep = null;
      done();
    }
  }
}
