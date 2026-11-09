import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/actions.dart';
import '../core/countries.dart';
import '../core/vies.dart';
import '../l10n.dart';
import '../main.dart';
import 'check_page.dart' show vies;
import 'result_card.dart';
import 'widgets.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _query = '';
  bool _onlyFav = false;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final q = _query.toLowerCase();
    final items = store.history.where((e) {
      if (_onlyFav && !e.favorite) return false;
      if (q.isEmpty) return true;
      return e.key.toLowerCase().contains(q) ||
          (e.name ?? '').toLowerCase().contains(q) ||
          (e.address ?? '').toLowerCase().contains(q);
    }).toList();
    final locale = Localizations.localeOf(context).toString();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    hintText: tr(context, 'Cerca nome, P.IVA, città…', 'Search name, VAT, city…'),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Icon(Icons.star, size: 18),
                selected: _onlyFav,
                tooltip: tr(context, 'Solo preferiti', 'Favourites only'),
                onSelected: (v) => setState(() => _onlyFav = v),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'csv') {
                    await shareCsv('cronologia_partite_iva.csv', [
                      ['Paese', 'Partita IVA', 'Valida', 'Denominazione', 'Indirizzo', 'Data', 'N. consultazione', 'Preferito'],
                      for (final e in store.history)
                        [
                          e.country,
                          e.vat,
                          e.valid ? 'SI' : 'NO',
                          e.name,
                          e.addressOneLine,
                          DateFormat('dd/MM/yyyy HH:mm').format(e.date),
                          e.consultation,
                          e.favorite ? 'SI' : '',
                        ],
                    ]);
                  } else if (v == 'clear') {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text(tr(context, 'Svuotare la cronologia?', 'Clear history?')),
                        content: Text(tr(context, 'I preferiti verranno mantenuti.',
                            'Favourites will be kept.')),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: Text(tr(context, 'Annulla', 'Cancel'))),
                          FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: Text(tr(context, 'Svuota', 'Clear'))),
                        ],
                      ),
                    );
                    if (ok == true) store.clearHistory();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'csv',
                    enabled: store.history.isNotEmpty,
                    child: ListTile(
                      leading: const Icon(Icons.table_view_outlined),
                      title: Text(tr(context, 'Esporta CSV', 'Export CSV')),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    enabled: store.history.isNotEmpty,
                    child: ListTile(
                      leading: const Icon(Icons.delete_sweep_outlined),
                      title: Text(tr(context, 'Svuota cronologia', 'Clear history')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      store.history.isEmpty
                          ? tr(context, 'Le verifiche effettuate compariranno qui.',
                              'Your checks will appear here.')
                          : tr(context, 'Nessun risultato.', 'No results.'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return Dismissible(
                      key: ValueKey(e.key),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Theme.of(context).colorScheme.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.delete_outline),
                      ),
                      onDismissed: (_) => store.remove(e.key),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.transparent,
                          child: Text(countryByCode(e.country)?.flag ?? e.country,
                              style: const TextStyle(fontSize: 24)),
                        ),
                        title: Text(
                          e.name ?? '${e.country} ${e.vat}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${e.country} ${e.vat} · ${DateFormat.yMd(locale).format(e.date)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (e.favorite)
                              Icon(Icons.star, color: Colors.amber.shade700, size: 20),
                            const SizedBox(width: 4),
                            Icon(
                              e.valid ? Icons.check_circle : Icons.cancel,
                              color: e.valid
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => HistoryDetailPage(initial: e))),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Dettaglio di una verifica passata, con possibilità di ripeterla.
class HistoryDetailPage extends StatefulWidget {
  final VatResult initial;
  const HistoryDetailPage({super.key, required this.initial});

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  late VatResult _r = widget.initial;
  bool _loading = false;

  Future<void> _recheck() async {
    final store = AppScope.read(context);
    setState(() => _loading = true);
    try {
      final r = await vies.check(_r.country, _r.vat,
          requesterCountry: store.requesterCountry, requesterVat: store.requesterVat);
      await store.addResult(r);
      if (mounted) setState(() => _r = r);
    } on ViesException catch (e) {
      if (mounted) showSnack(context, viesErrorMessage(context, e.code, _r.country));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context); // ricostruisce al cambio preferito
    return Scaffold(
      appBar: AppBar(title: Text('${_r.country} ${_r.vat}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ResultCard(result: _r),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loading ? null : _recheck,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: Text(tr(context, 'Verifica di nuovo', 'Check again')),
          ),
        ],
      ),
    );
  }
}
