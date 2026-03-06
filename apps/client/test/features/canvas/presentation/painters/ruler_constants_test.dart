import 'package:flutter_test/flutter_test.dart';
import 'package:vio_client/src/features/canvas/const/ruler.const.dart';

void main() {
  group('RulerConstants.computeLabelSkipFactor', () {
    test('returns 1 when scaled interval is comfortably readable', () {
      final factor = RulerConstants.computeLabelSkipFactor(96);

      expect(factor, 1);
    });

    test('increases skip factor when scaled interval is very small', () {
      final factor = RulerConstants.computeLabelSkipFactor(4);

      expect(factor, 12);
    });

    test('returns 1 for zero and negative intervals', () {
      expect(RulerConstants.computeLabelSkipFactor(0), 1);
      expect(RulerConstants.computeLabelSkipFactor(-10), 1);
    });

    test('is monotonic as interval shrinks', () {
      final readable = RulerConstants.computeLabelSkipFactor(48);
      final dense = RulerConstants.computeLabelSkipFactor(24);
      final veryDense = RulerConstants.computeLabelSkipFactor(8);

      expect(readable, lessThanOrEqualTo(dense));
      expect(dense, lessThanOrEqualTo(veryDense));
    });
  });

  group('RulerConstants.adjustMajorTickIntervalForZoom', () {
    test('keeps base interval when major ticks are already spaced enough', () {
      final interval = RulerConstants.adjustMajorTickIntervalForZoom(100, 1.0);

      expect(interval, 100);
    });

    test('expands major interval at low zoom', () {
      final interval = RulerConstants.adjustMajorTickIntervalForZoom(400, 0.04);

      expect(interval, 800);
    });

    test('returns base interval for invalid zoom', () {
      expect(RulerConstants.adjustMajorTickIntervalForZoom(400, 0), 400);
      expect(RulerConstants.adjustMajorTickIntervalForZoom(400, -1), 400);
    });
  });

  group('RulerConstants.computeMinorTickFractions', () {
    test('hides minor ticks when major spacing is too dense', () {
      final fractions = RulerConstants.computeMinorTickFractions(16);

      expect(fractions, isEmpty);
    });

    test('keeps only midpoint minor tick for medium spacing', () {
      final fractions = RulerConstants.computeMinorTickFractions(48);

      expect(fractions, const [0.5]);
    });

    test('renders full minor ticks when spacing is large', () {
      final fractions = RulerConstants.computeMinorTickFractions(100);

      expect(fractions.length, 9);
      expect(fractions.first, 0.1);
      expect(fractions[4], 0.5);
      expect(fractions.last, 0.9);
    });
  });
}
