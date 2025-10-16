import 'package:flutter_test/flutter_test.dart';
import 'package:speedy_cricket/speed_calc.dart';
void main() {
  test('calculateSpeedKmh - basic', () {
    // 20.12 meters in 1 second -> 20.12 m/s -> *3.6 = 72.432 km/h
    final kmh = calculateSpeedKmh(20.12, 1.0);
    expect(kmh, closeTo(72.432, 0.001));
  });

  test('calculateSpeedKmh - zero seconds', () {
    final kmh = calculateSpeedKmh(20.12, 0);
    expect(kmh, 0.0);
  });
}
