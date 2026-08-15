// Synthesized sound, matching Support/SoundPlayer.swift note tables.
// Uses the Web Audio API — nothing is loaded from disk.

const CUES = {
  pickUp: { notes: [[660, 0.07]], volume: 0.35 },
  place: { notes: [[523.25, 0.06], [659.25, 0.07]], volume: 0.5 },
  invalid: { notes: [[200, 0.09]], volume: 0.25 },
  clearSingle: { notes: [[659.25, 0.07], [783.99, 0.07], [1046.5, 0.12]], volume: 0.5 },
  clearCombo: { notes: [[659.25, 0.06], [830.61, 0.06], [987.77, 0.06], [1318.51, 0.16]], volume: 0.5 },
  button: { notes: [[880, 0.05]], volume: 0.35 },
  gameOver: { notes: [[587.33, 0.14], [493.88, 0.14], [392.0, 0.26]], volume: 0.5 },
  levelUp: {
    notes: [[523.25, 0.09], [659.25, 0.09], [783.99, 0.09], [1046.5, 0.1], [1318.51, 0.24]],
    volume: 0.5,
  },
};

class SoundPlayer {
  constructor(settings) {
    this.settings = settings;
    this.ctx = null;
    this.primed = false;
  }

  // Must be called from a user gesture to satisfy autoplay policies.
  unlock() {
    if (!this.ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return;
      this.ctx = new AC();
    }
    // iOS requires an audio node to actually START inside the user gesture —
    // calling resume() alone leaves the context silent until the first node is
    // started within a gesture. Games unlock() from touchstart/pointerdown, but
    // the first real cue is scheduled later in the render loop (not a gesture),
    // so nothing was audible until the user tapped a real <button> (the gear).
    // Priming one silent buffer here, synchronously, fully unlocks audio on the
    // very first gameplay gesture.
    if (!this.primed) {
      try {
        const buffer = this.ctx.createBuffer(1, 1, 22050);
        const source = this.ctx.createBufferSource();
        source.buffer = buffer;
        source.connect(this.ctx.destination);
        source.start(0);
        this.primed = true;
      } catch (e) { /* ignore — best-effort priming */ }
    }
    if (this.ctx.state === 'suspended') this.ctx.resume();
  }

  play(name) {
    if (!this.settings.isSoundEnabled) return;
    this.unlock();
    if (!this.ctx) return;

    const cue = CUES[name];
    if (!cue) return;
    let when = this.ctx.currentTime;
    for (const [freq, duration] of cue.notes) {
      this.scheduleNote(freq, duration, when, cue.volume);
      when += duration;
    }
  }

  // A sine plus a quiet octave, shaped by a short attack and a long decay,
  // mirroring ToneSynthesizer.renderNote.
  scheduleNote(freq, duration, startTime, volume) {
    const ctx = this.ctx;
    const gain = ctx.createGain();
    gain.connect(ctx.destination);

    const attack = 0.006;
    const peak = volume * 0.85;
    gain.gain.setValueAtTime(0.0001, startTime);
    gain.gain.linearRampToValueAtTime(peak, startTime + Math.min(attack, duration));
    // Approximate the (1 - progress)^1.6 decay with an exponential tail.
    gain.gain.exponentialRampToValueAtTime(0.0001, startTime + duration);

    const fundamental = ctx.createOscillator();
    fundamental.type = 'sine';
    fundamental.frequency.setValueAtTime(freq, startTime);

    const octave = ctx.createOscillator();
    octave.type = 'sine';
    octave.frequency.setValueAtTime(freq * 2, startTime);
    const octaveGain = ctx.createGain();
    octaveGain.gain.setValueAtTime(0.28 / 1.28, startTime);
    fundamental.connect(gain);
    octave.connect(octaveGain).connect(gain);

    fundamental.start(startTime);
    octave.start(startTime);
    fundamental.stop(startTime + duration + 0.02);
    octave.stop(startTime + duration + 0.02);
  }
}

// Light haptic feedback via the Vibration API (Android/Chrome; iOS ignores it).
class Haptics {
  constructor(settings) {
    this.settings = settings;
  }
  vibrate(pattern) {
    if (!this.settings.areHapticsEnabled) return;
    if (navigator.vibrate) navigator.vibrate(pattern);
  }
  pickUp() { this.vibrate(8); }
  place() { this.vibrate(12); }
  invalid() { this.vibrate([0, 20, 40, 20]); }
  clearLines() { this.vibrate(24); }
  gameOver() { this.vibrate([0, 30, 60, 30, 60, 40]); }
}

export { SoundPlayer, Haptics };
