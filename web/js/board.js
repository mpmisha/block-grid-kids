// The square playfield. Ported from BlockGridKids/Model/Board.swift.
import { DEFAULT_BOARD_SIZE } from './shapes.js';

const AVAILABLE_SIZES = [5, 8];

function key(pos) {
  return `${pos.row},${pos.col}`;
}

class Board {
  constructor(size = DEFAULT_BOARD_SIZE) {
    this.size = AVAILABLE_SIZES.includes(size) ? size : DEFAULT_BOARD_SIZE;
    // Row-major storage; each cell is null (empty) or a color index.
    this.cells = new Array(this.size * this.size).fill(null);
  }

  static get availableSizes() {
    return AVAILABLE_SIZES;
  }
  static get defaultSize() {
    return DEFAULT_BOARD_SIZE;
  }

  isInBounds(pos) {
    return pos.row >= 0 && pos.row < this.size && pos.col >= 0 && pos.col < this.size;
  }

  index(pos) {
    return pos.row * this.size + pos.col;
  }

  get(pos) {
    if (!this.isInBounds(pos)) return null;
    return this.cells[this.index(pos)];
  }

  set(pos, value) {
    if (!this.isInBounds(pos)) return;
    this.cells[this.index(pos)] = value;
  }

  isEmpty(pos) {
    if (!this.isInBounds(pos)) return false;
    return this.cells[this.index(pos)] === null;
  }

  get isCompletelyEmpty() {
    return this.cells.every((c) => c === null);
  }

  get filledCellCount() {
    return this.cells.reduce((t, c) => (c !== null ? t + 1 : t), 0);
  }

  // The positions a shape would occupy if anchored at origin.
  positions(shape, origin) {
    return shape.offsets.map((o) => ({ row: origin.row + o.row, col: origin.col + o.col }));
  }

  canPlace(shape, origin) {
    for (const pos of this.positions(shape, origin)) {
      if (!this.isInBounds(pos)) return false;
      if (this.cells[this.index(pos)] !== null) return false;
    }
    return true;
  }

  canPlaceAnywhere(shape) {
    return this.firstValidOrigin(shape) !== null;
  }

  firstValidOrigin(shape) {
    const maxRow = this.size - shape.height;
    const maxCol = this.size - shape.width;
    if (maxRow < 0 || maxCol < 0) return null;
    for (let row = 0; row <= maxRow; row++) {
      for (let col = 0; col <= maxCol; col++) {
        const origin = { row, col };
        if (this.canPlace(shape, origin)) return origin;
      }
    }
    return null;
  }

  place(shape, origin, colorIndex) {
    const filled = this.positions(shape, origin);
    for (const pos of filled) this.cells[this.index(pos)] = colorIndex;
    return filled;
  }

  completedLines() {
    const rows = [];
    const columns = [];
    for (let row = 0; row < this.size; row++) {
      let full = true;
      for (let c = 0; c < this.size; c++) {
        if (this.cells[row * this.size + c] === null) { full = false; break; }
      }
      if (full) rows.push(row);
    }
    for (let col = 0; col < this.size; col++) {
      let full = true;
      for (let r = 0; r < this.size; r++) {
        if (this.cells[r * this.size + col] === null) { full = false; break; }
      }
      if (full) columns.push(col);
    }
    return { rows, columns };
  }

  // Lines that would complete if the shape were placed, without mutating.
  linesCompletedIfPlaced(shape, origin) {
    if (!this.canPlace(shape, origin)) return { rows: [], columns: [] };
    const added = new Set(this.positions(shape, origin).map(key));
    const isFilled = (row, col) =>
      this.cells[row * this.size + col] !== null || added.has(`${row},${col}`);

    const rows = [];
    const columns = [];
    for (let row = 0; row < this.size; row++) {
      let full = true;
      for (let c = 0; c < this.size; c++) if (!isFilled(row, c)) { full = false; break; }
      if (full) rows.push(row);
    }
    for (let col = 0; col < this.size; col++) {
      let full = true;
      for (let r = 0; r < this.size; r++) if (!isFilled(r, col)) { full = false; break; }
      if (full) columns.push(col);
    }
    return { rows, columns };
  }

  // Empties rows/columns; returns every cleared position, de-duplicated.
  clear(rows, columns) {
    const cleared = new Map();
    for (const row of rows) {
      for (let col = 0; col < this.size; col++) cleared.set(`${row},${col}`, { row, col });
    }
    for (const col of columns) {
      for (let row = 0; row < this.size; row++) cleared.set(`${row},${col}`, { row, col });
    }
    for (const pos of cleared.values()) this.cells[this.index(pos)] = null;
    return Array.from(cleared.values());
  }

  removeAll() {
    this.cells = new Array(this.size * this.size).fill(null);
  }

  // Serialization helpers for save/restore.
  toJSON() {
    return { size: this.size, cells: this.cells };
  }

  static fromJSON(obj) {
    if (!obj) return null;
    const size = AVAILABLE_SIZES.includes(obj.size) ? obj.size : DEFAULT_BOARD_SIZE;
    if (!Array.isArray(obj.cells) || obj.cells.length !== size * size) return null;
    const board = new Board(size);
    board.cells = obj.cells.map((c) => (c === null || c === undefined ? null : c));
    return board;
  }
}

export { Board };
