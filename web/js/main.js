import './telemetry.js';
// Entry point: wires the DOM HUD/overlays to the canvas GameScene.
import { GameScene } from './scene.js';
import { SettingsStore } from './storage.js';
import { Board } from './board.js';
import { I18n } from './i18n.js';

// Resolve + apply the platform language before anything renders.
I18n.init();

const $ = (id) => document.getElementById(id);

// Apply all static (non-dynamic) strings from the active locale. Dynamic ones
// (best score, game-over title) are set where they render.
function applyStaticTranslations() {
  for (const el of document.querySelectorAll('[data-i18n]')) {
    el.textContent = I18n.t(el.getAttribute('data-i18n'));
  }
  for (const el of document.querySelectorAll('[data-i18n-aria]')) {
    el.setAttribute('aria-label', I18n.t(el.getAttribute('data-i18n-aria')));
  }
}

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

// Optional end-to-end test hook (only when explicitly requested via ?e2e=1).
if (new URLSearchParams(location.search).get('e2e') === '1') {
  window.__scene = scene;
}

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
  settingsBest.textContent = I18n.t('bestScoreLabel', { n: scene.engine.visibleBestScore });
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
  resetBtn.textContent = I18n.t('resetBest');
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
    resetBtn.textContent = I18n.t('resetConfirm');
    resetTimer = setTimeout(disarmReset, 3000);
    return;
  }
  disarmReset();
  scene.resetBestScore();
  settingsBest.textContent = I18n.t('bestScoreLabel', { n: 0 });
});

$('btn-close').addEventListener('click', () => {
  scene.sound.play('button');
  closeSettings();
});

// ---- Back to hub ----
// The hub can pass ?hub=<url>; otherwise fall back to the known hub site.
const HUB_URL = (() => {
  const param = new URLSearchParams(location.search).get('hub');
  if (param) { try { return new URL(param, location.href).href; } catch { /* ignore */ } }
  return 'https://mpmisha.github.io/playground/';
})();
const backHubBtn = $('btn-back-hub');
const embeddedInHub = window.self !== window.top;
backHubBtn.href = HUB_URL;
// Sound/Vibration are global now — controlled from the hub. When embedded, hide
// those rows and the redundant in-panel Back button (the hub's player bar does
// the going-back). Board size stays here; it's specific to this game.
if (embeddedInHub) {
  toggleSound.closest('.row').hidden = true;
  toggleHaptics.closest('.row').hidden = true;
  backHubBtn.hidden = true;
} else {
  backHubBtn.hidden = false;
}
backHubBtn.addEventListener('click', (e) => {
  scene.sound.play('button');
  // When embedded in the hub's in-app player, ask the hub to close us instead
  // of navigating the iframe (which would nest the hub inside the game frame).
  if (embeddedInHub) {
    e.preventDefault();
    try {
      window.parent.postMessage({ type: 'playground:back' }, new URL(HUB_URL).origin);
    } catch {
      window.parent.postMessage({ type: 'playground:back' }, '*');
    }
  }
});

settingsOverlay.querySelector('[data-dismiss="settings"]').addEventListener('click', closeSettings);

// ---- Game over overlay ----

const gameoverOverlay = $('gameover-overlay');

function openGameOver({ score, bestScore, isNewBest }) {
  $('go-emoji').textContent = isNewBest ? '🎉' : '🧩';
  $('go-title').textContent = isNewBest ? I18n.t('newBest') : I18n.t('noMoreMoves');
  $('go-score').textContent = String(score);
  $('go-best').textContent = `👑 ${I18n.t('bestBadge', { n: bestScore })}`;
  gameoverOverlay.hidden = false;
}

$('btn-play-again').addEventListener('click', () => {
  scene.sound.play('button');
  gameoverOverlay.hidden = true;
  scene.dismissOverlay();
  scene.startNewGame();
});

// ---- Localization ----
// Apply the resolved locale now, and re-apply live when the hub switches it
// (I18n dispatches to onChange after updating <html lang/dir>).
applyStaticTranslations();
I18n.onChange(() => {
  applyStaticTranslations();
  // Refresh any dynamic strings currently on screen.
  if (!settingsOverlay.hidden) syncSettingsUi();
  if (!gameoverOverlay.hidden) {
    openGameOver({
      score: scene.engine.score,
      bestScore: scene.engine.bestScore,
      isNewBest: $('go-emoji').textContent === '🎉',
    });
  }
});

// ---- Service worker (offline support) ----

if ('serviceWorker' in navigator) {
  // Auto-reload once when a new SW takes control so installed users get updates.
  let reloading = false;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (reloading) return;
    reloading = true;
    location.reload();
  });
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./service-worker.js').catch(() => {});
  });
}
