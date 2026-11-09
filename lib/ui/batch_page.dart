import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/actions.dart';
import '../core/countries.dart';
import '../core/vat_validator.dart';
import '../core/vies.dart';
import '../l10n.dart';
import '../main.dart';
import 'check_page.dart' show vies;
import 'history_page.dart';

enum _RowState { pending, running, valid, invalid, formatError, error }

class _Row {
  final String input;
  final String country;
  final String vat;
  _RowState state;
  VatResult? result;
  String? error;

  _Row(this.input, this.country, this.vat, this.state);
}

/// Verifica di un elenco di partite IVA (incollato o digitato), una per riga.
class BatchPage extends StatefulWidget {
  const BatchPage({super.key});

  @override
  State<BatchPage> createState() => _BatchPageState();
}

class _BatchPageState extends State<BatchPage> {
  final _ctrl = TextEditingController();
  List<_Row> _rows = [];
  bool _running = false;
  bool _stop = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<_Row> _parse(String defaultCountry) {
    final seen = <String>{};
    final rows = <_Row>[];
    for (final line in _ctrl.text.split(RegExp(r'[\n;,\t]'))) {
      if (line.trim().isEmpty) continue;
      final (c, n) = splitVat(line);
      final country = c?.code ?? defaultCountry;
      if (n.isEmpty || !seen.add('$country$n')) continue;
      final formal = checkVat(country, n);
      rows.add(_Row(line.trim(), country, n,
          formal == FormalCheck.invalid ? _RowState.formatError : _RowState.pending));
    }
    return rows;
  }

  Future<void> _run() async {
    final store = AppScope.read(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _rows = _parse(store.defaultCountry);
      _running = true;
      _stop = false;
    });
    for (final row in _rows) {
      if (_stop || !mounted) break;
      if (row.state != _RowState.pending) continue;
      setState(() => row.state = _RowState.running);
      // VIES limita le richieste concorrenti: una alla volta, con un nuovo
      // tentativo se il servizio è occupato.
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final r = await vies.check(row.country, row.vat,
              requesterCountry: store.requesterCountry,
              requesterVat: store.requesterVat);
          row.result = r;
          row.state = r.valid ? _RowState.valid : _RowState.invalid;
          row.error = null;
          await store.addResult(r);
          break;
        } on ViesException catch (e) {
          row.state = _RowState.error;
          if (mounted) row.error = viesErrorMessage(context, e.code, row.country);
          if (!e.transient) break;
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        }
      }
      if (mounted) setState(() {});
      await Future.delayed(const Duration(milliseconds: 400));
    }
    if (mounted) setState(() => _running = false);
  }

  Future<void> _export() {
    String state(_Row r) => switch (r.state) {
          _RowState.valid => 'VALIDA',
          _RowState.invalid => 'NON VALIDA',
          _RowState.formatError => 'FORMATO ERRATO',
          _RowState.error => 'ERRORE: ${r.error ?? ''}',
          _ => 'NON VERIFICATA',
        };
    return shareCsv('verifica_partite_iva.csv', [
      ['Paese', 'Partita IVA', 'Esito', 'Denominazione', 'Indirizzo', 'Data', 'N. consultazione'],
      for (final r in _rows)
        [
          r.country,
          r.vat,
          state(r),
          r.result?.name,
          r.result?.addressOneLine,
          r.result == null ? null : DateFormat('dd/MM/yyyy HH:mm').format(r.result!.date),
          r.result?.consultation,
        ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final done = _rows.where((r) => r.state != _RowState.pending && r.state != _RowState.running).length;
    final valid = _rows.where((r) => r.state == _RowState.valid).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr(
              context,
              'Incolla un elenco di partite IVA, una per riga. Senza prefisso si usa il paese predefinito (${store.defaultCountry}); '
                  'con prefisso (es. DE123456789) il paese indicato.',
              'Paste a list of VAT numbers, one per line. Numbers without prefix use the default country (${store.defaultCountry}); '
                  'prefixed numbers (e.g. DE123456789) use that country.'),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          minLines: 5,
          maxLines: 10,
          enabled: !_running,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: '00743110157\nDE811907980\nFR40303265045',
            alignLabelWithHint: true,
            suffixIcon: IconButton(
              tooltip: tr(context, 'Incolla', 'Paste'),
              icon: const Icon(Icons.content_paste),
              onPressed: _running
                  ? null
                  : () async {
                      final d = await Clipboard.getData(Clipboard.kTextPlain);
                      if (d?.text != null) {
                        _ctrl.text = _ctrl.text.isEmpty ? d!.text! : '${_ctrl.text}\n${d!.text}';
                        setState(() {});
                      }
                    },
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _running
                  ? OutlinedButton.icon(
                      onPressed: () => setState(() => _stop = true),
                      icon: const Icon(Icons.stop),
                      label: Text(tr(context, 'Interrompi', 'Stop')),
                    )
                  : FilledButton.icon(
                      onPressed: _ctrl.text.trim().isEmpty ? null : _run,
                      icon: const Icon(Icons.playlist_add_check),
                      label: Text(tr(context, 'Verifica tutte', 'Check all')),
                    ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: tr(context, 'Esporta CSV', 'Export CSV'),
              onPressed: _rows.isEmpty || _running ? null : _export,
              icon: const Icon(Icons.table_view_outlined),
            ),
          ],
        ),
        if (_rows.isNotEmpty) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _rows.isEmpty ? 0 : done / _rows.length),
          const SizedBox(height: 6),
          Text(tr(context, '$done di ${_rows.length} · $valid valide',
              '$done of ${_rows.length} · $valid valid')),
          const SizedBox(height: 8),
          for (final r in _rows) _tile(context, r),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, _Row r) {
    final cs = Theme.of(context).colorScheme;
    final Widget icon = switch (r.state) {
      _RowState.pending => const Icon(Icons.schedule, color: Colors.grey),
      _RowState.running => const SizedBox.square(
          dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)),
      _RowState.valid => const Icon(Icons.check_circle, color: Colors.green),
      _RowState.invalid => Icon(Icons.cancel, color: cs.error),
      _RowState.formatError => Icon(Icons.error_outline, color: cs.error),
      _RowState.error => const Icon(Icons.cloud_off, color: Colors.orange),
    };
    final subtitle = switch (r.state) {
      _RowState.formatError => tr(context, 'Formato errato', 'Wrong format'),
      _RowState.invalid => tr(context, 'Non valida in VIES', 'Not valid in VIES'),
      _RowState.error => r.error,
      _RowState.valid => r.result?.name ?? tr(context, 'Valida', 'Valid'),
      _ => null,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: icon,
      title: Text('${countryByCode(r.country)?.flag ?? ''} ${r.country} ${r.vat}'),
      subtitle: subtitle == null ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: r.result == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => HistoryDetailPage(initial: r.result!))),
    );
  }
}
