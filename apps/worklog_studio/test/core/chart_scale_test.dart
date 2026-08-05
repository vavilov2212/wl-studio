import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/feature/common/utils/chart_scale.dart';

void main() {
  group('chartScale', () {
    test('zero or negative maxHours -> default 1h interval, 4h maxY', () {
      expect(chartScale(0), equals((interval: 1.0, maxY: 4.0)));
      expect(chartScale(-3), equals((interval: 1.0, maxY: 4.0)));
    });

    test('2h max -> 0.5h interval, top gridline one step above (2.5h)', () {
      expect(chartScale(2), equals((interval: 0.5, maxY: 2.5)));
    });

    test('7.5h max -> 2h interval, maxY 10h', () {
      expect(chartScale(7.5), equals((interval: 2.0, maxY: 10.0)));
    });

    test('beyond the step table (60h) -> fallback interval 15h, maxY 75h', () {
      expect(chartScale(60), equals((interval: 15.0, maxY: 75.0)));
    });
  });
}
