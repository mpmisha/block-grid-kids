// Entry point: wires the DOM HUD/overlays to the canvas GameScene.
import { GameScene } from './scene.js';
import { SettingsStore } from './storage.js';
import { Board } from './board.js';

const $ = (id) => document.getElementById(id);

const canvas = $('game');

const dom = {
  header: $('hud'),
  hudScore: $('hud-score'),
  hudBest: $('hud-best'),
  bestBadge: $('best-badge'),
  onPresentSettings: openSettings,
  onPresentGameOver: openGameOver,
};

const scene = new GameScene(canvas, dom);

// Gear button.
$('gear').addEventListener('click', () => {
  scene.sound.unlock();
  scene.sound.play('button');
  scene.presentSettings();
});

// ---- Settings overlay ----

const settingsOverlay = $('settings-overlay');
const settingsBest = $('settings-best');
const boardSeg = $('board-size-seg');
const toggleSound = $('toggle-sound');
const toggleHaptics = $('toggle-haptics');
const resetBtn = $('btn-reset-best');
let resetArmed = false;
let resetTimer = null;

function syncSettingsUi() {
  settingsBest.textContent = `Best score: ${scene.engine.visibleBestScore}`;
  for (const btn of boardSeg.querySelectorAll('button')) {
    btn.classList.toggle('active', Number(btn.dataset.size) === scene.engine.boardSize);
  }
  toggleSound.classList.toggle('on', SettingsStore.isSoundEnabled);
  toggleHaptics.classList.toggle('on', SettingsStore.areHapticsEnabled);
  disarmReset();
}

function disarmReset() {
  resetArmed = false;
  if (resetTimer) { clearTimeout(resetTimer); resetTimer = null; }
  resetBtn.textContent = 'Reset Best Score';
}

function openSettings() {
  syncSettingsUi();
  settingsOverlay.hidden = false;
}

function closeSettings() {
  settingsOverlay.hidden = true;
  scene.dismissOverlay();
  disarmReset();
}

boardSeg.addEventListener('click', (e) => {
  const btn = e.target.closest('button');
  if (!btn) return;
  scene.sound.play('button');
  scene.changeBoardSize(Number(btn.dataset.size));
  syncSettingsUi();
});

toggleSound.addEventListener('click', () => {
  SettingsStore.isSoundEnabled = !SettingsStore.isSoundEnabled;
  toggleSound.classList.toggle('on', SettingsStore.isSoundEnabled);
  scene.sound.play('button');
});

toggleHaptics.addEventListener('click', () => {
  SettingsStore.areHapticsEnabled = !SettingsStore.areHapticsEnabled;
  toggleHaptics.classList.toggle('on', SettingsStore.areHapticsEnabled);
  scene.haptics.pickUp();
});

$('btn-new-game').addEventListener('click', () => {
  scene.sound.play('button');
  closeSettings();
  scene.startNewGame();
});

// Reset requires a confirming second tap.
resetBtn.addEventListener('click', () => {
  scene.sound.play('button');
  if (!resetArmed) {
    resetArmed = true;
    resetBtn.textContent = 'Tap again to confirm';
    resetTimer = setTimeout(disarmReset, 3000);
    return;
  }
  disarmReset();
  scene.resetBestScore();
  settingsBest.textContent = 'Best score: 0';
});

$('btn-close').addEventListener('click', () => {
  scene.sound.play('button');
  closeSettings();
});

settingsOverlay.querySelector('[data-dismiss="settings"]').addEventListener('click', closeSettings);

// ---- Game over overlay ----

const gameoverOverlay = $('gameover-overlay');

function openGameOver({ score, bestScore, isNewBest }) {
  $('go-emoji').textContent = isNewBest ? '🎉' : '🧩';
  $('go-title').textContent = isNewBest ? 'New Best!' : 'No More Moves';
  $('go-score').textContent = String(score);
  $('go-best').textContent = `👑 Best: ${bestScore}`;
  gameoverOverlay.hidden = false;
}

$('btn-play-again').addEventListener('click', () => {
  scene.sound.play('button');
  gameoverOverlay.hidden = true;
  scene.dismissOverlay();
  scene.startNewGame();
});

// ---- Service worker (offline support) ----

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./service-worker.js').catch(() => {});
  });
}
