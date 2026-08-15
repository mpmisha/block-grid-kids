// Playground i18n (v1) — shared contract across the hub + every game.
// English (LTR, fallback) and Hebrew (RTL). Hub and all games are the SAME
// origin (https://mpmisha.github.io), so localStorage['lang'] is shared and the
// hub drives the language for every game. This module only READS/APPLIES it.

const LANGS = ['en', 'he'];
const STORAGE_KEY = 'lang';

const DICT = {
  en: {
    // --- Settings panel ---
    settings: 'Settings',
    bestScoreLabel: 'Best score: {n}',
    board: 'Board',
    sound: 'Sound',
    vibration: 'Vibration',
    newGame: 'New Game',
    resetBest: 'Reset Best Score',
    resetConfirm: 'Tap again to confirm',
    backToGames: 'Back to Games',
    close: 'Close',
    // --- Game over panel ---
    noMoreMoves: 'No More Moves',
    newBest: 'New Best!',
    yourScore: 'Your score',
    bestBadge: 'Best: {n}',
    playAgain: 'Play Again',
    // --- Canvas praise / banners ---
    praiseAmazing: 'AMAZING!',
    praiseSuper: 'SUPER!',
    praiseGreat: 'GREAT!',
    praiseOnFire: 'ON FIRE!',
    praiseNice: 'NICE!',
    noMovesLeft: 'No Moves Left',
    perfect: 'PERFECT!',
    level: 'LEVEL {n}',
  },
  he: {
    settings: 'הגדרות',
    bestScoreLabel: 'שיא: {n}',
    board: 'לוח',
    sound: 'צליל',
    vibration: 'רטט',
    newGame: 'משחק חדש',
    resetBest: 'איפוס שיא',
    resetConfirm: 'הקישו שוב לאישור',
    backToGames: 'חזרה למשחקים',
    close: 'סגירה',
    noMoreMoves: 'אין עוד מהלכים',
    newBest: 'שיא חדש!',
    yourScore: 'הניקוד שלכם',
    bestBadge: 'שיא: {n}',
    playAgain: 'שחקו שוב',
    praiseAmazing: 'מדהים!',
    praiseSuper: 'סופר!',
    praiseGreat: 'מצוין!',
    praiseOnFire: 'בוערים!',
    praiseNice: 'יופי!',
    noMovesLeft: 'אין עוד מהלכים',
    perfect: 'מושלם!',
    level: 'שלב {n}',
  },
};

function isValid(lang) {
  return LANGS.includes(lang);
}

// Auto-detect from the browser; treat he/legacy iw as Hebrew.
function detect() {
  const list = navigator.languages && navigator.languages.length
    ? navigator.languages
    : [navigator.language || ''];
  for (const raw of list) {
    const code = String(raw).toLowerCase();
    if (code.startsWith('he') || code.startsWith('iw')) return 'he';
  }
  return 'he';
}

// Resolution order: (1) URL ?lang= if valid; (2) localStorage; (3) auto-detect.
function resolveInitial() {
  const urlLang = new URLSearchParams(location.search).get('lang');
  if (isValid(urlLang)) {
    // A valid explicit ?lang= is persisted so the choice sticks.
    try { localStorage.setItem(STORAGE_KEY, urlLang); } catch { /* ignore */ }
    return urlLang;
  }
  let stored = null;
  try { stored = localStorage.getItem(STORAGE_KEY); } catch { /* ignore */ }
  if (isValid(stored)) return stored;
  // Never persist an auto-detected value — only explicit choices are stored.
  return detect();
}

let current = 'en';
const listeners = new Set();

function apply(lang) {
  current = isValid(lang) ? lang : 'en';
  const el = document.documentElement;
  el.setAttribute('lang', current);
  el.setAttribute('dir', current === 'he' ? 'rtl' : 'ltr');
  for (const fn of listeners) {
    try { fn(current); } catch { /* ignore listener errors */ }
  }
}

function t(key, params) {
  const table = DICT[current] || DICT.en;
  let str = (key in table) ? table[key] : (DICT.en[key] ?? key);
  if (params) {
    for (const k of Object.keys(params)) {
      str = str.replace(`{${k}}`, String(params[k]));
    }
  }
  return str;
}

const I18n = {
  get lang() { return current; },
  get isRTL() { return current === 'he'; },
  t,
  onChange(fn) { listeners.add(fn); return () => listeners.delete(fn); },
  // Explicit change (e.g. from a hub postMessage). Persists the choice.
  setLang(lang) {
    if (!isValid(lang)) return;
    try { localStorage.setItem(STORAGE_KEY, lang); } catch { /* ignore */ }
    apply(lang);
  },
  init() {
    apply(resolveInitial());
    // Live language switching from the hub (same-origin postMessage only).
    window.addEventListener('message', (e) => {
      if (e.origin !== location.origin) return;
      const data = e.data;
      if (data && data.type === 'playground:lang' && isValid(data.lang)) {
        // Reflect the hub's live choice; persist so a reload keeps it.
        try { localStorage.setItem(STORAGE_KEY, data.lang); } catch { /* ignore */ }
        apply(data.lang);
      }
    });
    return current;
  },
};

export { I18n };
