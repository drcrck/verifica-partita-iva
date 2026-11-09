import 'package:flutter/material.dart';

import '../core/countries.dart';
import '../core/vat_validator.dart';
import '../l10n.dart';

/// Menu a tendina dei paesi, con bandiera e (opzionale) stato del servizio.
class CountryDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final Map<String, bool> availability;
  final String? label;

  const CountryDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.availability = const {},
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final en = isEn(context);
    final sorted = [...countries]
      ..sort((a, b) => a.name(en).compareTo(b.name(en)));
    return DropdownButtonFormField<String>(
      key: ValueKey(value), // ricostruisce quando il paese cambia da codice
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label ?? tr(context, 'Paese', 'Country')),
      items: [
        for (final c in sorted)
          DropdownMenuItem(
            value: c.code,
            child: Row(
              children: [
                Text(c.flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(child: Text('${c.name(en)} (${c.code})')),
                if (availability[c.code] == false)
                  Tooltip(
                    message: tr(context, 'Servizio nazionale non disponibile',
                        'National service unavailable'),
                    child: const Icon(Icons.cloud_off, size: 18, color: Colors.orange),
                  ),
              ],
            ),
          ),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }
}

/// Riga che descrive l'esito del controllo formale offline.
class FormalCheckHint extends StatelessWidget {
  final FormalCheck check;
  const FormalCheckHint(this.check, {super.key});

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (check) {
      FormalCheck.checksumOk => (
          Icons.check_circle_outline,
          Colors.green,
          tr(context, 'Formato e cifra di controllo corretti',
              'Format and check digit are correct')
        ),
      FormalCheck.formatOk => (
          Icons.info_outline,
          Colors.blueGrey,
          tr(context, 'Formato corretto', 'Format is correct')
        ),
      FormalCheck.invalid => (
          Icons.error_outline,
          Theme.of(context).colorScheme.error,
          tr(context, 'Formato o cifra di controllo errati',
              'Wrong format or check digit')
        ),
    };
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: TextStyle(color: color))),
      ],
    );
  }
}

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}
