// SkinSelection + SkinCatalog. Ported from Model/SkinSelection.swift and
// Support/Skin.swift.
import { rgb, white } from './color.js';

const OPTION_COUNT = 4;

function clampOption(value) {
  return ((value % OPTION_COUNT) + OPTION_COUNT) % OPTION_COUNT;
}

class SkinSelection {
  constructor(blockPalette, surfacePalette, blockStyle, surfaceStyle) {
    this.blockPalette = clampOption(blockPalette);
    this.surfacePalette = clampOption(surfacePalette);
    this.blockStyle = clampOption(blockStyle);
    this.surfaceStyle = clampOption(surfaceStyle);
  }

  static get initial() {
    return new SkinSelection(0, 0, 0, 0);
  }

  equals(other) {
    return other &&
      this.blockPalette === other.blockPalette &&
      this.surfacePalette === other.surfacePalette &&
      this.blockStyle === other.blockStyle &&
      this.surfaceStyle === other.surfaceStyle;
  }

  differenceCount(other) {
    let count = 0;
    if (this.blockPalette !== other.blockPalette) count++;
    if (this.surfacePalette !== other.surfacePalette) count++;
    if (this.blockStyle !== other.blockStyle) count++;
    if (this.surfaceStyle !== other.surfaceStyle) count++;
    return count;
  }

  // A fresh permutation differing on >= 2 axes.
  next() {
    const rand = () => Math.floor(Math.random() * OPTION_COUNT);
    for (let i = 0; i < 24; i++) {
      const candidate = new SkinSelection(rand(), rand(), rand(), rand());
      if (candidate.differenceCount(this) >= 2) return candidate;
    }
    return new SkinSelection(
      this.blockPalette + 1, this.surfacePalette, this.blockStyle + 1, this.surfaceStyle,
    );
  }

  toJSON() {
    return {
      blockPalette: this.blockPalette,
      surfacePalette: this.surfacePalette,
      blockStyle: this.blockStyle,
      surfaceStyle: this.surfaceStyle,
    };
  }

  static fromJSON(obj) {
    if (!obj) return null;
    return new SkinSelection(
      obj.blockPalette ?? 0, obj.surfacePalette ?? 0,
      obj.blockStyle ?? 0, obj.surfaceStyle ?? 0,
    );
  }
}

// Block styles / surface styles as string enums.
const BlockStyle = { candy: 0, brick: 1, liquid: 2, metal: 3 };
const SurfaceStyle = { plain: 0, dots: 1, stripes: 2, waves: 3 };

const BLOCK_PALETTES = [
  { name: 'Candy', colors: [
    rgb(0.60, 0.40, 0.93), rgb(0.32, 0.79, 0.40), rgb(0.98, 0.60, 0.20), rgb(0.26, 0.62, 0.97),
    rgb(0.97, 0.40, 0.65), rgb(0.99, 0.83, 0.25), rgb(0.25, 0.82, 0.82), rgb(0.95, 0.36, 0.36),
  ] },
  { name: 'Sunset', colors: [
    rgb(0.98, 0.42, 0.35), rgb(0.99, 0.72, 0.24), rgb(0.94, 0.34, 0.56), rgb(0.74, 0.38, 0.80),
    rgb(0.99, 0.86, 0.42), rgb(0.93, 0.53, 0.24), rgb(0.86, 0.27, 0.42), rgb(0.99, 0.62, 0.56),
  ] },
  { name: 'Ocean', colors: [
    rgb(0.20, 0.72, 0.86), rgb(0.30, 0.85, 0.72), rgb(0.34, 0.55, 0.93), rgb(0.56, 0.86, 0.95),
    rgb(0.16, 0.60, 0.63), rgb(0.62, 0.52, 0.93), rgb(0.42, 0.88, 0.60), rgb(0.96, 0.79, 0.44),
  ] },
  { name: 'Neon', colors: [
    rgb(0.99, 0.20, 0.62), rgb(0.56, 0.96, 0.22), rgb(0.15, 0.92, 0.92), rgb(0.70, 0.30, 0.99),
    rgb(0.99, 0.91, 0.16), rgb(0.99, 0.46, 0.10), rgb(0.25, 0.56, 0.99), rgb(0.99, 0.28, 0.30),
  ] },
];

const SURFACE_PALETTES = [
  { name: 'Twilight',
    backgroundTop: rgb(0.36, 0.47, 0.86), backgroundBottom: rgb(0.22, 0.26, 0.60),
    boardBackground: rgb(0.16, 0.18, 0.32, 0.55), emptyCell: rgb(0.20, 0.22, 0.36, 0.95),
    pattern: white(1.0, 0.07) },
  { name: 'Grape',
    backgroundTop: rgb(0.54, 0.34, 0.82), backgroundBottom: rgb(0.26, 0.14, 0.44),
    boardBackground: rgb(0.21, 0.12, 0.35, 0.58), emptyCell: rgb(0.28, 0.18, 0.44, 0.95),
    pattern: rgb(1.0, 0.86, 0.60, 0.08) },
  { name: 'Forest',
    backgroundTop: rgb(0.20, 0.64, 0.56), backgroundBottom: rgb(0.07, 0.28, 0.30),
    boardBackground: rgb(0.06, 0.21, 0.23, 0.58), emptyCell: rgb(0.11, 0.28, 0.30, 0.95),
    pattern: rgb(0.80, 1.0, 0.86, 0.08) },
  { name: 'Ember',
    backgroundTop: rgb(0.70, 0.33, 0.30), backgroundBottom: rgb(0.30, 0.12, 0.19),
    boardBackground: rgb(0.24, 0.10, 0.15, 0.58), emptyCell: rgb(0.33, 0.16, 0.21, 0.95),
    pattern: rgb(1.0, 0.82, 0.55, 0.09) },
];

const SkinCatalog = {
  blockPalettes: BLOCK_PALETTES,
  surfacePalettes: SURFACE_PALETTES,
  selection: SkinSelection.initial,
  revision: 0,

  apply(newSelection) {
    if (this.selection.equals(newSelection)) return false;
    this.selection = newSelection;
    this.revision += 1;
    return true;
  },

  reset() {
    this.apply(SkinSelection.initial);
  },

  get blockPalette() {
    return BLOCK_PALETTES[this.selection.blockPalette % BLOCK_PALETTES.length];
  },
  get surfacePalette() {
    return SURFACE_PALETTES[this.selection.surfacePalette % SURFACE_PALETTES.length];
  },
  get blockStyle() {
    return this.selection.blockStyle % 4;
  },
  get surfaceStyle() {
    return this.selection.surfaceStyle % 4;
  },
};

export { SkinSelection, SkinCatalog, BlockStyle, SurfaceStyle, OPTION_COUNT };
