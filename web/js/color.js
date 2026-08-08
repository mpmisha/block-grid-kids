// Color helpers mirroring BlockGridKids/Support/UIColor+Adjust.swift.

// rgba in 0..1 floats -> CSS string.
function css({ r, g, b, a = 1 }) {
  return `rgba(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(b * 255)}, ${a})`;
}

function rgb(r, g, b, a = 1) {
  return { r, g, b, a };
}

function white(w, a = 1) {
  return { r: w, g: w, b: w, a };
}

function clamp01(x) {
  return Math.max(0, Math.min(1, x));
}

function rgbToHsb({ r, g, b }) {
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const delta = max - min;
  let h = 0;
  if (delta !== 0) {
    if (max === r) h = ((g - b) / delta) % 6;
    else if (max === g) h = (b - r) / delta + 2;
    else h = (r - g) / delta + 4;
    h /= 6;
    if (h < 0) h += 1;
  }
  const s = max === 0 ? 0 : delta / max;
  return { h, s, v: max };
}

function hsbToRgb({ h, s, v }, a = 1) {
  const i = Math.floor(h * 6);
  const f = h * 6 - i;
  const p = v * (1 - s);
  const q = v * (1 - f * s);
  const t = v * (1 - (1 - f) * s);
  let r, g, b;
  switch (i % 6) {
    case 0: r = v; g = t; b = p; break;
    case 1: r = q; g = v; b = p; break;
    case 2: r = p; g = v; b = t; break;
    case 3: r = p; g = q; b = v; break;
    case 4: r = t; g = p; b = v; break;
    default: r = v; g = p; b = q; break;
  }
  return { r, g, b, a };
}

// Same hue, brightness scaled by factor (matches adjustingBrightness).
function adjustBrightness(color, factor) {
  const hsb = rgbToHsb(color);
  hsb.v = clamp01(hsb.v * factor);
  return hsbToRgb(hsb, color.a ?? 1);
}

// Blend toward white by amount (0..1) (matches lightened).
function lightened(color, amount) {
  const c = clamp01(amount);
  return {
    r: color.r + (1 - color.r) * c,
    g: color.g + (1 - color.g) * c,
    b: color.b + (1 - color.b) * c,
    a: color.a ?? 1,
  };
}

export { css, rgb, white, adjustBrightness, lightened, clamp01 };
