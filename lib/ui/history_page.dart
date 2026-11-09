import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';

import '../core/actions.dart';
import '../core/countries.dart';
import '../core/vies.dart';
import '../l10n.dart';
import '../main.dart';
import 'check_page.dart' show vies;
import 'result_card.dart';
import 'theme.dart';
import 'widgets.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _query = '';
  bool _onlyFav = false;
  String? _selectedKey; // solo nel layout a due pannelli

  Future<void> _menu(String v, dynamic store) async {
    if (v == 'csv') {
      await shareCsv('cronologia_partite_iva.csv', [
        [
          'Paese',
          'Partita IVA',
          'Valida',
          'Denominazione',
          'Indirizzo',
          'Data',
          'N. consultazione',
          'Preferito',
        ],
        for (final e in store.history as List<VatResult>)
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
          content: Text(
            tr(
              context,
              'I preferiti verranno mantenuti.',
              'Favourites will be kept.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr(context, 'Annulla', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr(context, 'Svuota', 'Clear')),
            ),
          ],
        ),
      );
      if (ok == true) {
        store.clearHistory();
        setState(() => _selectedKey = null);
      }
    }
  }

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

    return LayoutBuilder(
      builder: (context, c) {
        final twoPane = c.maxWidth >= expandedWidth;
        final selected = twoPane
            ? store.history.where((e) => e.key == _selectedKey).firstOrNull
            : null;

        final list = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search),
                        hintText: tr(
                          context,
                          'Cerca nome, P.IVA, città…',
                          'Search name, VAT, city…',
                        ),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Icon(
                      Icons.star,
                      size: 18,
                      semanticLabel: tr(
                        context,
                        'Solo preferiti',
                        'Favourites only',
                      ),
                    ),
                    selected: _onlyFav,
                    tooltip: tr(context, 'Solo preferiti', 'Favourites only'),
                    onSelected: (v) => setState(() => _onlyFav = v),
                  ),
                  PopupMenuButton<String>(
                    tooltip: tr(context, 'Altre azioni', 'More actions'),
                    onSelected: (v) => _menu(v, store),
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
                          title: Text(
                            tr(context, 'Svuota cronologia', 'Clear history'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? _EmptyHistory(hasHistory: store.history.isNotEmpty)
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final e = items[i];
                        return HistoryTile(
                          entry: e,
                          selected: twoPane && e.key == _selectedKey,
                          onDelete: () => store.remove(e.key),
                          onTap: () {
                            if (twoPane) {
                              setState(() => _selectedKey = e.key);
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => HistoryDetailPage(initial: e),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        );

        if (!twoPane) return Readable(child: list);

        // Tablet in orizzontale: elenco + dettaglio affiancati.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 400, child: list),
            const VerticalDivider(width: 1),
            Expanded(
              child: selected == null
                  ? Center(
                      child: Text(
                        tr(
                          context,
                          'Seleziona una verifica dall\'elenco.',
                          'Select a check from the list.',
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : HistoryDetailView(
                      key: ValueKey(selected.key),
                      initial: selected,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final bool hasHistory;
  const _EmptyHistory({required this.hasHistory});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                hasHistory ? Icons.search_off : Icons.history,
                size: 56,
                color: cs.outlineVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasHistory
                  ? tr(context, 'Nessun risultato.', 'No results.')
                  : tr(
                      context,
                      'Le verifiche effettuate compariranno qui.',
                      'Your checks will appear here.',
                    ),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Riga della cronologia: l'esito è nel testo letto da TalkBack, non solo nel colore.
class HistoryTile extends StatelessWidget {
  final VatResult entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const HistoryTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final cs = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    final locale = Localizations.localeOf(context).toString();
    final status = e.valid
        ? tr(context, 'valida', 'valid')
        : tr(context, 'non valida', 'not valid');

    return Dismissible(
      key: ValueKey(e.key),
      direction: DismissDirection.endToStart,
      background: Container(
        color: cs.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
      ),
      onDismissed: (_) => onDelete(),
      child: Semantics(
        // Azione alternativa allo swipe per chi usa TalkBack.
        customSemanticsActions: {
          CustomSemanticsAction(label: tr(context, 'Elimina', 'Delete')):
              onDelete,
        },
        child: ListTile(
          selected: selected,
          leading: SizedBox(
            width: 40,
            child: Center(
              child: Flag(
                countryByCode(e.country)?.flag ?? e.country,
                size: 26,
              ),
            ),
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
                Icon(
                  Icons.star,
                  color: st.favorite,
                  size: 20,
                  semanticLabel: tr(context, 'preferito', 'favourite'),
                ),
              const SizedBox(width: 4),
              Icon(
                e.valid ? Icons.check_circle : Icons.cancel,
                color: e.valid ? st.success : cs.error,
                semanticLabel: status,
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Dettaglio di una verifica passata, con possibilità di ripeterla.
/// Usato sia come pagina (telefono) sia come pannello (tablet).
class HistoryDetailView extends StatefulWidget {
  final VatResult initial;
  const HistoryDetailView({super.key, required this.initial});

  @override
  State<HistoryDetailView> createState() => _HistoryDetailViewState();
}

class _HistoryDetailViewState extends State<HistoryDetailView> {
  late VatResult _r = widget.initial;
  bool _loading = false;

  Future<void> _recheck() async {
    final store = AppScope.read(context);
    setState(() => _loading = true);
    try {
      final r = await vies.check(
        _r.country,
        _r.vat,
        requesterCountry: store.requesterCountry,
        requesterVat: store.requesterVat,
      );
      await store.addResult(r);
      if (mounted) setState(() => _r = r);
    } on ViesException catch (e) {
      if (mounted) {
        showSnack(context, viesErrorMessage(context, e.code, _r.country));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context); // ricostruisce al cambio preferito
    return Readable(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ResultCard(result: _r),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loading ? null : _recheck,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(tr(context, 'Verifica di nuovo', 'Check again')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryDetailPage extends StatelessWidget {
  final VatResult initial;
  const HistoryDetailPage({super.key, required this.initial});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${initial.country} ${initial.vat}')),
      body: HistoryDetailView(initial: initial),
    );
  }
}
