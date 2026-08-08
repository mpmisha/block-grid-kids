// Shape templates and the shape library.
// Ported 1:1 from BlockGridKids/Model/ShapeTemplate.swift.

const DEFAULT_BOARD_SIZE = 8;

function normalize(offsets) {
  if (offsets.length === 0) return offsets;
  const minRow = Math.min(...offsets.map((o) => o.row));
  const minCol = Math.min(...offsets.map((o) => o.col));
  return offsets.map((o) => ({ row: o.row - minRow, col: o.col - minCol }));
}

class ShapeTemplate {
  constructor(id, cells, weight) {
    this.id = id;
    this.offsets = normalize(cells.map(([r, c]) => ({ row: r, col: c })));
    this.weight = weight;
  }
  get cellCount() {
    return this.offsets.length;
  }
  get width() {
    return Math.max(...this.offsets.map((o) => o.col)) + 1;
  }
  get height() {
    return Math.max(...this.offsets.map((o) => o.row)) + 1;
  }
}

// The full catalogue. Weights match the Swift ShapeLibrary exactly.
const ALL_SHAPES = [
  // Dot
  new ShapeTemplate('dot', [[0, 0]], 5),

  // Horizontal and vertical bars
  new ShapeTemplate('bar-h2', [[0, 0], [0, 1]], 10),
  new ShapeTemplate('bar-v2', [[0, 0], [1, 0]], 10),
  new ShapeTemplate('bar-h3', [[0, 0], [0, 1], [0, 2]], 9),
  new ShapeTemplate('bar-v3', [[0, 0], [1, 0], [2, 0]], 9),
  new ShapeTemplate('bar-h4', [[0, 0], [0, 1], [0, 2], [0, 3]], 5),
  new ShapeTemplate('bar-v4', [[0, 0], [1, 0], [2, 0], [3, 0]], 5),
  new ShapeTemplate('bar-h5', [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]], 2),
  new ShapeTemplate('bar-v5', [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]], 2),

  // Squares and rectangles
  new ShapeTemplate('square2', [[0, 0], [0, 1], [1, 0], [1, 1]], 9),
  new ShapeTemplate('square3',
    [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2], [2, 0], [2, 1], [2, 2]], 1.5),
  new ShapeTemplate('rect23', [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2]], 3),
  new ShapeTemplate('rect32', [[0, 0], [0, 1], [1, 0], [1, 1], [2, 0], [2, 1]], 3),

  // Small corners (3 cells)
  new ShapeTemplate('corner-tl', [[0, 0], [0, 1], [1, 0]], 7),
  new ShapeTemplate('corner-tr', [[0, 0], [0, 1], [1, 1]], 7),
  new ShapeTemplate('corner-bl', [[0, 0], [1, 0], [1, 1]], 7),
  new ShapeTemplate('corner-br', [[0, 1], [1, 0], [1, 1]], 7),

  // Large corners (5 cells)
  new ShapeTemplate('bigcorner-tl', [[0, 0], [0, 1], [0, 2], [1, 0], [2, 0]], 2.5),
  new ShapeTemplate('bigcorner-tr', [[0, 0], [0, 1], [0, 2], [1, 2], [2, 2]], 2.5),
  new ShapeTemplate('bigcorner-bl', [[0, 0], [1, 0], [2, 0], [2, 1], [2, 2]], 2.5),
  new ShapeTemplate('bigcorner-br', [[0, 2], [1, 2], [2, 0], [2, 1], [2, 2]], 2.5),

  // L / J tetrominoes
  new ShapeTemplate('l-1', [[0, 0], [1, 0], [2, 0], [2, 1]], 3),
  new ShapeTemplate('l-2', [[0, 1], [1, 1], [2, 1], [2, 0]], 3),
  new ShapeTemplate('l-3', [[0, 0], [0, 1], [1, 0], [2, 0]], 3),
  new ShapeTemplate('l-4', [[0, 0], [0, 1], [1, 1], [2, 1]], 3),

  // T tetrominoes
  new ShapeTemplate('t-up', [[0, 1], [1, 0], [1, 1], [1, 2]], 3),
  new ShapeTemplate('t-down', [[0, 0], [0, 1], [0, 2], [1, 1]], 3),
  new ShapeTemplate('t-left', [[0, 1], [1, 0], [1, 1], [2, 1]], 3),
  new ShapeTemplate('t-right', [[0, 0], [1, 0], [1, 1], [2, 0]], 3),

  // S / Z tetrominoes
  new ShapeTemplate('s-h', [[0, 1], [0, 2], [1, 0], [1, 1]], 2),
  new ShapeTemplate('z-h', [[0, 0], [0, 1], [1, 1], [1, 2]], 2),
  new ShapeTemplate('s-v', [[0, 0], [1, 0], [1, 1], [2, 1]], 2),
  new ShapeTemplate('z-v', [[0, 1], [1, 0], [1, 1], [2, 0]], 2),
];

const ShapeLibrary = {
  all: ALL_SHAPES,

  // The shapes worth offering on a board of `size` cells per side.
  shapes(boardSize) {
    if (boardSize >= DEFAULT_BOARD_SIZE) return ALL_SHAPES;
    return ALL_SHAPES.filter((s) => s.width <= 3 && s.height <= 3 && s.cellCount <= 4);
  },

  rescueShapes: ALL_SHAPES
    .filter((s) => s.cellCount <= 2)
    .sort((a, b) => a.cellCount - b.cellCount),

  shape(id) {
    return ALL_SHAPES.find((s) => s.id === id) || null;
  },
};

export { ShapeTemplate, ShapeLibrary, DEFAULT_BOARD_SIZE };
