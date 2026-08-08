// Tray generation. Ported from Model/ShapeGenerator.swift.
import { ShapeLibrary } from './shapes.js';

const GameConfiguration = {
  colorCount: 8,
  traySize: 3,
  maxTraySetAttempts: 40,
};

let pieceCounter = 0;
function nextPieceId() {
  pieceCounter += 1;
  return `p${pieceCounter}-${Math.random().toString(36).slice(2, 8)}`;
}

// A concrete piece sitting in the tray.
class Piece {
  constructor(shape, colorIndex, id = nextPieceId()) {
    this.id = id;
    this.shape = shape;
    this.colorIndex = colorIndex;
  }
  get cellCount() {
    return this.shape.cellCount;
  }
  toJSON() {
    return { id: this.id, shapeId: this.shape.id, colorIndex: this.colorIndex };
  }
  static fromJSON(obj) {
    if (!obj) return null;
    const shape = ShapeLibrary.shape(obj.shapeId);
    if (!shape) return null;
    return new Piece(shape, obj.colorIndex, obj.id);
  }
}

class ShapeGenerator {
  randomColorIndex() {
    return Math.floor(Math.random() * GameConfiguration.colorCount);
  }

  randomShape(boardSize) {
    const shapes = ShapeLibrary.shapes(boardSize);
    const totalWeight = shapes.reduce((t, s) => t + s.weight, 0);
    if (totalWeight <= 0) return shapes[0];
    let roll = Math.random() * totalWeight;
    for (const shape of shapes) {
      roll -= shape.weight;
      if (roll <= 0) return shape;
    }
    return shapes[shapes.length - 1];
  }

  makePiece(board) {
    return new Piece(this.randomShape(board.size), this.randomColorIndex());
  }

  // Guarantees at least one piece is playable whenever any shape can be placed.
  makeTray(board) {
    for (let attempt = 0; attempt < GameConfiguration.maxTraySetAttempts; attempt++) {
      const candidate = [];
      for (let i = 0; i < GameConfiguration.traySize; i++) candidate.push(this.makePiece(board));
      if (candidate.some((p) => board.canPlaceAnywhere(p.shape))) return candidate;
    }

    const rescue = ShapeLibrary.rescueShapes.find((s) => board.canPlaceAnywhere(s));
    if (rescue) {
      const pieces = [new Piece(rescue, this.randomColorIndex())];
      while (pieces.length < GameConfiguration.traySize) pieces.push(this.makePiece(board));
      return pieces;
    }

    const pieces = [];
    for (let i = 0; i < GameConfiguration.traySize; i++) pieces.push(this.makePiece(board));
    return pieces;
  }
}

export { ShapeGenerator, Piece, GameConfiguration };
