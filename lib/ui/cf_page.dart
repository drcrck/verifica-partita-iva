import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/codice_fiscale.dart';
import '../core/vat_validator.dart';
import '../l10n.dart';
import 'widgets.dart';

/// Verifica offline del codice fiscale italiano.
class CodiceFiscalePage extends StatefulWidget {
  const CodiceFiscalePage({super.key});

  @override
  State<CodiceFiscalePage> createState() => _CodiceFiscalePageState();
}

class _CodiceFiscalePageState extends State<CodiceFiscalePage> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _ctrl.text.toUpperCase().replaceAll(RegExp(r'\s'), '');
    final cs = Theme.of(context).colorScheme;

    Widget? body;
    if (RegExp(r'^\d{11}$').hasMatch(v)) {
      // Il codice fiscale di società ed enti coincide con la partita IVA.
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, 'Codice fiscale numerico (società o ente)',
              'Numeric tax code (company or entity)')),
          const SizedBox(height: 8),
          FormalCheckHint(checkVat('IT', v)),
          const SizedBox(height: 8),
          Text(
            tr(context, 'Per verificarne l\'esistenza usa la scheda "Verifica".',
                'Use the "Check" tab to verify that it exists.'),
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      );
    } else if (v.length == 16) {
      final info = checkCodiceFiscale(v);
      if (!info.valid) {
        final reason = switch (info.error) {
          'checksum' => tr(context, 'Il carattere di controllo non corrisponde.',
              'The check character does not match.'),
          'date' => tr(context, 'La data di nascita non è valida.', 'Invalid birth date.'),
          _ => tr(context, 'Formato non valido.', 'Invalid format.'),
        };
        body = ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.cancel, color: cs.error, size: 36),
          title: Text(tr(context, 'Codice fiscale non valido', 'Invalid tax code')),
          subtitle: Text(reason),
        );
      } else {
        final locale = Localizations.localeOf(context).toString();
        final age = _age(info.birthDate!);
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified, color: Colors.green, size: 36),
              title: Text(tr(context, 'Codice fiscale formalmente corretto',
                  'Tax code is formally correct')),
              subtitle: info.omocodia
                  ? Text(tr(context, 'Variante per omocodia', 'Homocode variant'))
                  : null,
            ),
            const Divider(),
            _kv(context, tr(context, 'Sesso', 'Sex'),
                info.sex == 'F' ? tr(context, 'Femmina', 'Female') : tr(context, 'Maschio', 'Male')),
            _kv(context, tr(context, 'Data di nascita', 'Birth date'),
                '${DateFormat.yMMMMd(locale).format(info.birthDate!)}  ($age ${tr(context, 'anni', 'years')})'),
            _kv(
                context,
                info.bornAbroad
                    ? tr(context, 'Stato estero (cod.)', 'Foreign country (code)')
                    : tr(context, 'Comune (cod. catastale)', 'Municipality (code)'),
                info.belfiore!),
            const SizedBox(height: 12),
            Text(
              tr(
                  context,
                  'Il controllo è solo formale: l\'esistenza del codice si verifica sul sito dell\'Agenzia delle Entrate. '
                      'Per persone nate prima del ${DateTime.now().year - 100} il secolo potrebbe essere ambiguo.',
                  'This is a formal check only: existence can be verified on the Agenzia delle Entrate website. '
                      'For people born before ${DateTime.now().year - 100} the century may be ambiguous.'),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
        );
      }
    } else if (v.isNotEmpty) {
      body = Text(
        tr(context, '${v.length}/16 caratteri', '${v.length}/16 characters'),
        style: TextStyle(color: cs.onSurfaceVariant),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _ctrl,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          maxLength: 16,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z]'))],
          decoration: InputDecoration(
            labelText: tr(context, 'Codice fiscale', 'Italian tax code'),
            hintText: 'RSSMRA85T10A562S',
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(_ctrl.clear),
                  ),
          ),
          style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1.5),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        ?body,
      ],
    );
  }

  int _age(DateTime b) {
    final n = DateTime.now();
    var a = n.year - b.year;
    if (n.month < b.month || (n.month == b.month && n.day < b.day)) a--;
    return a;
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 170,
              child: Text(k,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Expanded(child: SelectableText(v)),
          ],
        ),
      );
}
