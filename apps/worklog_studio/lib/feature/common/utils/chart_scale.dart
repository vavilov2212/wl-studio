// Returns interval and chartMaxY as a clean pair.
// chartMaxY is always (numSteps+1)*interval so the top gridline is a round
// number one step above the tallest bar - no floating 7.2h or 0.6h labels.
({double interval, double maxY}) chartScale(double maxHours) {
  const steps = [0.25, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 12.0];
  if (maxHours <= 0) return (interval: 1.0, maxY: 4.0);
  final raw = maxHours / 4;
  final interval =
      steps.firstWhere((v) => v >= raw, orElse: () => (raw / 5).ceil() * 5.0);
  final numSteps = (maxHours / interval).ceil() + 1;
  return (interval: interval, maxY: interval * numSteps);
}
