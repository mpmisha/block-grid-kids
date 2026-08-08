// The game engine. Ported from Model/GameEngine.swift.
import { Board } from './board.js';
import { ScoringEngine } from './scoring.js';
import { ShapeGenerator, Piece, GameConfiguration } from './generator.js';
import { SkinSelection } from './skins.js';

// Per-board-size best score, kept in localStorage.
class HighScoreStore {
  constructor() {
    // One-time migration of a legacy single best score onto the 8x8 key.
    const legacy = localStorage.getItem('bestScore');
    if (legacy !== null) {
      const key = `bestScore.${Board.defaultSize}`;
      if (localStorage.getItem(key) === null) {
        localStorage.setItem(key, String(Math.max(0, parseInt(legacy, 10) || 0)));
      }
      localStorage.removeItem('bestScore');
    }
  }
  bestScore(size) {
    return parseInt(localStorage.getItem(`bestScore.${size}`) || '0', 10) || 0;
  }
  setBestScore(score, size) {
    localStorage.setItem(`bestScore.${size}`, String(Math.max(0, score)));
  }
}

class GameEngine {
  constructor(boardSize = Board.defaultSize, scoreStore = new HighScoreStore(), generator = new ShapeGenerator()) {
    this.scoreStore = scoreStore;
    this.generator = generator;
    this.board = new Board(boardSize);
    this.tray = [];
    this.score = 0;
    this.streak = 0;
    this.isGameOver = false;
    this.perfectClears = 0;
    this.skin = SkinSelection.initial;
    this.bestScore = this.scoreStore.bestScore(this.board.size);
    this.baselineBestScore = this.bestScore;
    this.startNewGame();
  }

  get level() {
    return this.perfectClears + 1;
  }
  get boardSize() {
    return this.board.size;
  }
  get visibleBestScore() {
    return this.isGameOver ? this.bestScore : this.baselineBestScore;
  }
  get remainingPieces() {
    return this.tray.filter((p) => p !== null && p !== undefined);
  }

  changeBoardSize(newSize) {
    if (!Board.availableSizes.includes(newSize) || newSize === this.board.size) return false;
    this.board = new Board(newSize);
    this.bestScore = this.scoreStore.bestScore(newSize);
    this.startNewGame();
    return true;
  }

  startNewGame() {
    this.board.removeAll();
    this.score = 0;
    this.streak = 0;
    this.isGameOver = false;
    this.perfectClears = 0;
    this.skin = SkinSelection.initial;
    this.baselineBestScore = this.bestScore;
    this.refillTray();
  }

  refillTray() {
    this.tray = this.generator.makeTray(this.board);
  }

  piece(index) {
    return this.tray[index] ?? null;
  }

  canPlace(index, origin) {
    const piece = this.piece(index);
    if (!piece) return false;
    return this.board.canPlace(piece.shape, origin);
  }

  hasAvailableMove() {
    return this.remainingPieces.some((p) => this.board.canPlaceAnywhere(p.shape));
  }

  linesCompleted(index, origin) {
    const piece = this.piece(index);
    if (!piece) return { rows: [], columns: [] };
    return this.board.linesCompletedIfPlaced(piece.shape, origin);
  }

  // Attempts a placement; returns a result object or null if illegal.
  place(index, origin) {
    if (this.isGameOver) return null;
    const piece = this.piece(index);
    if (!piece || !this.board.canPlace(piece.shape, origin)) return null;

    const result = {
      placedPositions: [], clearedRows: [], clearedColumns: [], clearedPositions: [],
      breakdown: null, streak: 0, totalScore: 0, didRefillTray: false,
      isNewBestScore: false, isGameOver: false, isPerfectClear: false, level: 1,
    };

    result.placedPositions = this.board.place(piece.shape, origin, piece.colorIndex);
    this.tray[index] = null;

    const completed = this.board.completedLines();
    result.clearedRows = completed.rows;
    result.clearedColumns = completed.columns;

    const didClear = completed.rows.length + completed.columns.length > 0;
    if (didClear) {
      this.streak += 1;
      result.clearedPositions = this.board.clear(completed.rows, completed.columns);
    } else {
      this.streak = 0;
    }
    result.streak = this.streak;

    if (didClear && this.board.filledCellCount === 0) {
      result.isPerfectClear = true;
      this.perfectClears += 1;
      this.skin = this.skin.next();
    }
    result.level = this.level;

    result.breakdown = ScoringEngine.breakdown(
      piece.cellCount, completed.rows.length + completed.columns.length, this.streak,
    );
    this.score += result.breakdown.total;
    result.totalScore = this.score;

    if (this.remainingPieces.length === 0) {
      this.refillTray();
      result.didRefillTray = true;
    }

    if (this.score > this.bestScore) {
      this.bestScore = this.score;
      this.scoreStore.setBestScore(this.score, this.board.size);
    }

    if (!this.hasAvailableMove()) this.isGameOver = true;
    result.isGameOver = this.isGameOver;
    result.isNewBestScore = this.isGameOver && this.score > this.baselineBestScore;

    // Convenience flags mirroring PlacementResult.
    result.clearedLineCount = result.clearedRows.length + result.clearedColumns.length;
    result.didClearLines = result.clearedLineCount > 0;
    return result;
  }

  resetBestScore() {
    this.bestScore = 0;
    this.baselineBestScore = 0;
    this.scoreStore.setBestScore(0, this.board.size);
  }

  makeSnapshot() {
    return {
      board: this.board.toJSON(),
      tray: this.tray.map((p) => (p ? p.toJSON() : null)),
      score: this.score,
      streak: this.streak,
      isGameOver: this.isGameOver,
      baselineBestScore: this.baselineBestScore,
      perfectClears: this.perfectClears,
      skin: this.skin.toJSON(),
    };
  }

  restore(snapshot) {
    if (!snapshot || snapshot.isGameOver) return false;
    const board = Board.fromJSON(snapshot.board);
    if (!board || board.size !== this.board.size) return false;
    if (!Array.isArray(snapshot.tray) || snapshot.tray.length !== GameConfiguration.traySize) return false;
    const filled = board.filledCellCount;
    if (!(filled > 0 || (snapshot.score || 0) > 0)) return false;

    this.board = board;
    this.tray = snapshot.tray.map((p) => (p ? Piece.fromJSON(p) : null));
    this.score = Math.max(0, snapshot.score || 0);
    this.streak = Math.max(0, snapshot.streak || 0);
    this.isGameOver = false;
    const baseline = snapshot.baselineBestScore ?? this.bestScore;
    this.baselineBestScore = Math.min(this.bestScore, Math.max(0, baseline));
    this.perfectClears = Math.max(0, snapshot.perfectClears || 0);
    this.skin = SkinSelection.fromJSON(snapshot.skin) || SkinSelection.initial;

    if (this.remainingPieces.length === 0) this.refillTray();
    if (!this.hasAvailableMove()) this.isGameOver = true;
    return !this.isGameOver;
  }
}

export { GameEngine, HighScoreStore };
