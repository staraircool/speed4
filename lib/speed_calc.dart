double calculateSpeedKmh(double meters, double seconds) {
  if (seconds <= 0) return 0.0;
  final ms = meters / seconds;
  return ms * 3.6;
}
