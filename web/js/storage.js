// Player settings + saved-game persistence via localStorage.
// Ported from Support/SettingsStore.swift.
import { Board } from './board.js';

const KEYS = {
  sound: 'soundEnabled',
  haptics: 'hapticsEnabled',
  boardSize: 'boardSize',
  savedGame: 'savedGame',
};

function readBool(key, fallback) {
  const v = localStorage.getItem(key);
  if (v === null) return fallback;
  return v === 'true';
}

const SettingsStore = {
  get isSoundEnabled() {
    return readBool(KEYS.sound, true);
  },
  set isSoundEnabled(value) {
    localStorage.setItem(KEYS.sound, value ? 'true' : 'false');
  },
  get areHapticsEnabled() {
    return readBool(KEYS.haptics, true);
  },
  set areHapticsEnabled(value) {
    localStorage.setItem(KEYS.haptics, value ? 'true' : 'false');
  },
  get boardSize() {
    const stored = parseInt(localStorage.getItem(KEYS.boardSize) || '', 10);
    return Board.availableSizes.includes(stored) ? stored : Board.defaultSize;
  },
  set boardSize(value) {
    if (!Board.availableSizes.includes(value)) return;
    localStorage.setItem(KEYS.boardSize, String(value));
  },
};

const GameStateStore = {
  save(snapshot) {
    try {
      localStorage.setItem(KEYS.savedGame, JSON.stringify(snapshot));
    } catch (_) {
      // Storage may be unavailable/evicted; the game still plays fine.
    }
  },
  loadSnapshot() {
    const raw = localStorage.getItem(KEYS.savedGame);
    if (!raw) return null;
    try {
      return JSON.parse(raw);
    } catch (_) {
      return null;
    }
  },
  clear() {
    localStorage.removeItem(KEYS.savedGame);
  },
};

export { SettingsStore, GameStateStore };
