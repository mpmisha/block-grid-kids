// Pure scoring rules. Ported from BlockGridKids/Model/ScoringEngine.swift.

const ScoringEngine = {
  placementPoints(cellCount) {
    return Math.max(0, cellCount);
  },

  // 10 x lines^2, so simultaneous clears are worth far more.
  lineClearPoints(lineCount) {
    if (lineCount <= 0) return 0;
    return 10 * lineCount * lineCount;
  },

  // 5 x (streak - 1), awarded only when the placement cleared something.
  streakPoints(streak, didClear) {
    if (!didClear || streak <= 1) return 0;
    return 5 * (streak - 1);
  },

  breakdown(cellCount, lineCount, streak) {
    const placementPoints = ScoringEngine.placementPoints(cellCount);
    const lineClearPoints = ScoringEngine.lineClearPoints(lineCount);
    const streakPoints = ScoringEngine.streakPoints(streak, lineCount > 0);
    return {
      placementPoints,
      lineClearPoints,
      streakPoints,
      get total() {
        return placementPoints + lineClearPoints + streakPoints;
      },
    };
  },
};

export { ScoringEngine };
