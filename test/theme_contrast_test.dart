import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifica_piva/ui/theme.dart';

double _ratio(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  final hi = x > y ? x : y, lo = x > y ? y : x;
  return (hi + .05) / (lo + .05);
}

void main() {
  for (final b in Brightness.values) {
    test('contrasto colori di esito ($b)', () {
      final t = buildTheme(b);
      final cs = t.colorScheme;
      final s = t.extension<StatusColors>()!;
      // Testo normale: AA 4.5:1 su tutte le superfici usate.
      for (final bg in [
        cs.surface,
        cs.surfaceContainerLow,
        cs.surfaceContainer,
      ]) {
        expect(
          _ratio(s.success, bg),
          greaterThanOrEqualTo(4.5),
          reason: 'success',
        );
        expect(
          _ratio(s.warning, bg),
          greaterThanOrEqualTo(4.5),
          reason: 'warning',
        );
        // Icona (elemento grafico): 3:1.
        expect(
          _ratio(s.favorite, bg),
          greaterThanOrEqualTo(3),
          reason: 'favorite',
        );
      }
      expect(
        _ratio(s.onSuccessContainer, s.successContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(_ratio(s.success, s.successContainer), greaterThanOrEqualTo(3));
    });
  }
}
