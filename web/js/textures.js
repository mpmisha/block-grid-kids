// Block + empty-cell + background textures rendered to offscreen canvases.
// Ported from Scene/BlockTextureCache.swift and Scene/BackgroundNode.swift.
import { css, adjustBrightness, lightened } from './color.js';
import { SkinCatalog, BlockStyle, SurfaceStyle } from './skins.js';

const BLOCK_CORNER_RADIUS_RATIO = 0.16;
const DPR = Math.min(window.devicePixelRatio || 1, 3);

function roundRect(ctx, x, y, w, h, r) {
  const radius = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.arcTo(x + w, y, x + w, y + h, radius);
  ctx.arcTo(x + w, y + h, x, y + h, radius);
  ctx.arcTo(x, y + h, x, y, radius);
  ctx.arcTo(x, y, x + w, y, radius);
  ctx.closePath();
}

function makeCanvas(side) {
  const c = document.createElement('canvas');
  c.width = Math.max(1, Math.round(side * DPR));
  c.height = Math.max(1, Math.round(side * DPR));
  const ctx = c.getContext('2d');
  ctx.scale(DPR, DPR);
  return { canvas: c, ctx };
}

const bodyDarkening = { [BlockStyle.candy]: 0.62, [BlockStyle.brick]: 0.55, [BlockStyle.liquid]: 0.66, [BlockStyle.metal]: 0.58 };
const faceRadiusScale = { [BlockStyle.candy]: 0.60, [BlockStyle.brick]: 0.35, [BlockStyle.liquid]: 0.95, [BlockStyle.metal]: 0.30 };

class BlockTextureCache {
  constructor() {
    this.filled = new Map();
    this.empty = null;
    this.side = 0;
    this.skinRevision = -1;
  }

  prepare(cellSide) {
    const rounded = Math.round(cellSide * 2) / 2;
    if (rounded !== this.side) {
      this.side = rounded;
      this.flush();
    }
  }

  invalidateForSkinChange() {
    this.flush();
  }

  flush() {
    this.filled.clear();
    this.empty = null;
    this.skinRevision = SkinCatalog.revision;
  }

  flushIfSkinChanged() {
    if (this.skinRevision !== SkinCatalog.revision) this.flush();
  }

  filledTexture(colorIndex) {
    this.flushIfSkinChanged();
    if (this.filled.has(colorIndex)) return this.filled.get(colorIndex);
    const colors = SkinCatalog.blockPalette.colors;
    const color = colors[((colorIndex % colors.length) + colors.length) % colors.length];
    const tex = this.makeFilled(color, Math.max(1, this.side), SkinCatalog.blockStyle);
    this.filled.set(colorIndex, tex);
    return tex;
  }

  emptyTexture() {
    this.flushIfSkinChanged();
    if (this.empty) return this.empty;
    this.empty = this.makeEmpty(Math.max(1, this.side), SkinCatalog.surfaceStyle);
    return this.empty;
  }

  makeFilled(color, side, style) {
    const { canvas, ctx } = makeCanvas(side);

    // Outer body (bevel) fills the cell.
    const bodyInset = side * 0.012;
    const bodyRadius = side * BLOCK_CORNER_RADIUS_RATIO;
    ctx.fillStyle = css(adjustBrightness(color, bodyDarkening[style]));
    roundRect(ctx, bodyInset, bodyInset, side - bodyInset * 2, side - bodyInset * 2, bodyRadius);
    ctx.fill();

    // Raised face, nudged up so the bottom reads as a shadow.
    const faceInset = side * 0.13;
    const fx = faceInset;
    const fy = faceInset * 0.70;
    const fw = side - faceInset * 2;
    const fh = side - faceInset * 2.25;
    ctx.fillStyle = css(color);
    roundRect(ctx, fx, fy, fw, fh, bodyRadius * faceRadiusScale[style]);
    ctx.fill();

    ctx.save();
    roundRect(ctx, fx, fy, fw, fh, bodyRadius * faceRadiusScale[style]);
    ctx.clip();
    const face = { x: fx, y: fy, w: fw, h: fh, midX: fx + fw / 2, midY: fy + fh / 2, maxX: fx + fw, maxY: fy + fh };
    switch (style) {
      case BlockStyle.candy: this.drawCandyFace(ctx, face, side); break;
      case BlockStyle.brick: this.drawBrickFace(ctx, face, side, color); break;
      case BlockStyle.liquid: this.drawLiquidFace(ctx, face, color); break;
      case BlockStyle.metal: this.drawMetalFace(ctx, face, side, color); break;
    }
    ctx.restore();
    return canvas;
  }

  drawCandyFace(ctx, face, side) {
    ctx.fillStyle = 'rgba(255,255,255,0.22)';
    ctx.fillRect(face.x, face.y, face.w, face.h * 0.42);
    const hs = side * 0.16;
    ctx.fillStyle = 'rgba(255,255,255,0.45)';
    roundRect(ctx, face.x + side * 0.06, face.y + side * 0.06, hs, hs * 0.6, hs * 0.3);
    ctx.fill();
  }

  drawBrickFace(ctx, face, side, color) {
    const courses = 3;
    const courseHeight = face.h / courses;
    const joint = Math.max(1, side * 0.035);

    ctx.fillStyle = 'rgba(255,255,255,0.14)';
    ctx.fillRect(face.x, face.y, face.w, courseHeight * 0.5);

    ctx.fillStyle = css(adjustBrightness(color, 0.58));
    for (let i = 1; i < courses; i++) {
      const y = face.y + courseHeight * i;
      ctx.fillRect(face.x, y - joint / 2, face.w, joint);
    }
    for (let i = 0; i < courses; i++) {
      const y = face.y + courseHeight * i;
      const x = i % 2 === 0 ? face.midX : face.x + face.w * 0.22;
      ctx.fillRect(x - joint / 2, y, joint, courseHeight);
      if (i % 2 !== 0) {
        ctx.fillRect(face.x + face.w * 0.78 - joint / 2, y, joint, courseHeight);
      }
    }
    ctx.fillStyle = css(adjustBrightness(color, 0.80));
    ctx.fillRect(face.x, face.maxY - side * 0.05, face.w, side * 0.05);
  }

  drawLiquidFace(ctx, face, color) {
    const grad = ctx.createLinearGradient(face.midX, face.y, face.midX, face.maxY);
    grad.addColorStop(0, css(lightened(color, 0.42)));
    grad.addColorStop(0.55, css(color));
    grad.addColorStop(1, css(adjustBrightness(color, 0.74)));
    ctx.fillStyle = grad;
    ctx.fillRect(face.x, face.y, face.w, face.h);

    ctx.fillStyle = 'rgba(255,255,255,0.50)';
    ctx.beginPath();
    ctx.ellipse(face.x + face.w * 0.35, face.y + face.h * 0.25, face.w * 0.23, face.h * 0.15, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = 'rgba(255,255,255,0.34)';
    ctx.beginPath();
    ctx.ellipse(face.x + face.w * 0.72, face.y + face.h * 0.305, face.w * 0.08, face.h * 0.065, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = 'rgba(255,255,255,0.16)';
    ctx.fillRect(face.x, face.maxY - face.h * 0.12, face.w, face.h * 0.12);
  }

  drawMetalFace(ctx, face, side, color) {
    const grad = ctx.createLinearGradient(face.midX, face.y, face.midX, face.maxY);
    grad.addColorStop(0, css(adjustBrightness(color, 0.78)));
    grad.addColorStop(0.34, css(lightened(color, 0.34)));
    grad.addColorStop(0.62, css(adjustBrightness(color, 0.70)));
    grad.addColorStop(1, css(lightened(color, 0.12)));
    ctx.fillStyle = grad;
    ctx.fillRect(face.x, face.y, face.w, face.h);

    ctx.fillStyle = 'rgba(255,255,255,0.07)';
    const step = Math.max(2, side * 0.07);
    for (let y = face.y; y < face.maxY; y += step) {
      ctx.fillRect(face.x, y, face.w, Math.max(0.5, step * 0.18));
    }

    ctx.fillStyle = 'rgba(255,255,255,0.26)';
    ctx.beginPath();
    ctx.moveTo(face.x, face.maxY - face.h * 0.18);
    ctx.lineTo(face.x + face.w * 0.42, face.y);
    ctx.lineTo(face.x + face.w * 0.66, face.y);
    ctx.lineTo(face.x, face.maxY);
    ctx.closePath();
    ctx.fill();
  }

  makeEmpty(side, style) {
    const { canvas, ctx } = makeCanvas(side);
    const inset = side * 0.025;
    const rect = { x: inset, y: inset, w: side - inset * 2, h: side - inset * 2 };
    rect.midX = rect.x + rect.w / 2;
    rect.midY = rect.y + rect.h / 2;
    rect.maxX = rect.x + rect.w;
    rect.maxY = rect.y + rect.h;
    const radius = side * BLOCK_CORNER_RADIUS_RATIO;

    ctx.fillStyle = css(SkinCatalog.surfacePalette.emptyCell);
    roundRect(ctx, rect.x, rect.y, rect.w, rect.h, radius);
    ctx.fill();

    ctx.save();
    roundRect(ctx, rect.x, rect.y, rect.w, rect.h, radius);
    ctx.clip();
    const mark = 'rgba(255,255,255,0.06)';
    switch (style) {
      case SurfaceStyle.plain:
        break;
      case SurfaceStyle.dots: {
        ctx.fillStyle = mark;
        const r = side * 0.10;
        ctx.beginPath();
        ctx.arc(rect.midX, rect.midY, r, 0, Math.PI * 2);
        ctx.fill();
        break;
      }
      case SurfaceStyle.stripes: {
        ctx.fillStyle = mark;
        ctx.save();
        ctx.translate(rect.midX, rect.midY);
        ctx.rotate(-Math.PI / 4);
        const w = side * 0.12;
        for (let o = -side; o <= side; o += side * 0.34) {
          ctx.fillRect(o, -side, w, side * 2);
        }
        ctx.restore();
        break;
      }
      case SurfaceStyle.waves: {
        ctx.strokeStyle = mark;
        ctx.lineWidth = Math.max(1, side * 0.05);
        ctx.beginPath();
        ctx.moveTo(rect.x, rect.midY);
        ctx.bezierCurveTo(
          rect.x + rect.w * 0.3, rect.midY - rect.h * 0.22,
          rect.maxX - rect.w * 0.3, rect.midY + rect.h * 0.22,
          rect.maxX, rect.midY,
        );
        ctx.stroke();
        break;
      }
    }
    ctx.restore();

    ctx.strokeStyle = 'rgba(255,255,255,0.06)';
    ctx.lineWidth = Math.max(1, side * 0.02);
    roundRect(ctx, rect.x, rect.y, rect.w, rect.h, radius);
    ctx.stroke();
    return canvas;
  }
}

// The gradient backdrop plus the skin's pattern, rendered to a canvas.
function makeBackgroundCanvas(width, height) {
  const c = document.createElement('canvas');
  c.width = Math.max(2, Math.round(width * DPR));
  c.height = Math.max(2, Math.round(height * DPR));
  const ctx = c.getContext('2d');
  ctx.scale(DPR, DPR);

  const surface = SkinCatalog.surfacePalette;
  const grad = ctx.createLinearGradient(0, 0, 0, height);
  grad.addColorStop(0, css(surface.backgroundTop));
  grad.addColorStop(1, css(surface.backgroundBottom));
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, width, height);

  drawBackgroundPattern(ctx, SkinCatalog.surfaceStyle, width, height, css(surface.pattern));
  return c;
}

function drawBackgroundPattern(ctx, style, width, height, tint) {
  ctx.fillStyle = tint;
  ctx.strokeStyle = tint;
  switch (style) {
    case SurfaceStyle.plain:
      break;
    case SurfaceStyle.dots: {
      const spacing = 46;
      const radius = 5;
      let row = 0;
      for (let y = spacing / 2; y < height + spacing; y += spacing) {
        const offset = row % 2 === 0 ? 0 : spacing / 2;
        for (let x = spacing / 2 + offset; x < width + spacing; x += spacing) {
          ctx.beginPath();
          ctx.arc(x, y, radius, 0, Math.PI * 2);
          ctx.fill();
        }
        row++;
      }
      break;
    }
    case SurfaceStyle.stripes: {
      ctx.save();
      ctx.translate(width / 2, height / 2);
      ctx.rotate(-Math.PI / 4);
      const reach = Math.max(width, height) * 1.5;
      const w = 22;
      for (let o = -reach; o < reach; o += w * 2.6) {
        ctx.fillRect(o, -reach, w, reach * 2);
      }
      ctx.restore();
      break;
    }
    case SurfaceStyle.waves: {
      ctx.lineWidth = 3;
      const amplitude = 14;
      const wavelength = 120;
      for (let y = 40; y < height + amplitude; y += 58) {
        ctx.beginPath();
        ctx.moveTo(-wavelength, y);
        for (let x = -wavelength; x < width + wavelength; x += wavelength) {
          ctx.bezierCurveTo(
            x + wavelength * 0.25, y - amplitude,
            x + wavelength * 0.75, y + amplitude,
            x + wavelength, y,
          );
        }
        ctx.stroke();
      }
      break;
    }
  }
}

export { BlockTextureCache, makeBackgroundCanvas, roundRect };
