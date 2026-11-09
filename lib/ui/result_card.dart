import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/actions.dart';
import '../core/countries.dart';
import '../core/vat_validator.dart';
import '../core/vies.dart';
import '../l10n.dart';
import '../main.dart';
import 'widgets.dart';

/// Scheda con l'esito di una verifica e le azioni disponibili.
class ResultCard extends StatelessWidget {
  final VatResult result;
  const ResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final cs = Theme.of(context).colorScheme;
    final store = AppScope.of(context);
    final c = countryByCode(r.country);
    final fav = store.isFavorite(r.key);
    final formal = checkVat(r.country, r.vat);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: r.valid ? Colors.green.withValues(alpha: .15) : cs.errorContainer,
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Icon(r.valid ? Icons.verified : Icons.cancel,
                    color: r.valid ? Colors.green.shade700 : cs.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r.valid
                        ? tr(context, 'Partita IVA valida', 'Valid VAT number')
                        : tr(context, 'Non valida in VIES', 'Not valid in VIES'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'Preferito', 'Favourite'),
                  icon: Icon(fav ? Icons.star : Icons.star_border,
                      color: fav ? Colors.amber.shade700 : null),
                  onPressed: () => store.toggleFavorite(r.key),
                ),
              ],
            ),
          ),
          if (r.valid && r.address != null && streetViewEnabled)
            _StreetView(address: r.addressOneLine!),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.name != null)
                  SelectableText(r.name!,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                if (r.address != null) ...[
                  const SizedBox(height: 4),
                  SelectableText(r.address!.trim()),
                ],
                if (r.valid && r.name == null)
                  Text(
                    tr(context,
                        'Questo paese non comunica denominazione e indirizzo a VIES.',
                        'This country does not share name and address with VIES.'),
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                if (!r.valid && formal != FormalCheck.invalid)
                  Text(
                    r.country == 'IT'
                        ? tr(
                            context,
                            'Il numero è formalmente corretto ma non risulta in VIES: '
                                "l'archivio contiene solo le partite IVA italiane abilitate alle "
                                'operazioni intracomunitarie. Potrebbe anche essere cessata.',
                            'The number is formally correct but not in VIES: only Italian '
                                'VAT numbers enabled for intra-EU trade are listed. It may also be closed.')
                        : tr(
                            context,
                            'Il numero è formalmente corretto ma non risulta in VIES '
                                '(non abilitato a operazioni intracomunitarie o cessato).',
                            'The number is formally correct but not registered in VIES '
                                '(not enabled for intra-EU trade, or deregistered).'),
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                const Divider(height: 24),
                _kv(context, tr(context, 'Partita IVA', 'VAT number'),
                    '${c?.flag ?? ''} ${r.country} ${r.vat}', copy: '${r.country}${r.vat}'),
                _kv(context, tr(context, 'Verificata il', 'Checked on'),
                    DateFormat.yMd(Localizations.localeOf(context).toString())
                        .add_Hm()
                        .format(r.date)),
                if (r.consultation != null)
                  _kv(context, tr(context, 'N. consultazione', 'Consultation no.'),
                      r.consultation!, copy: r.consultation),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (r.address != null)
                  ActionChip(
                    avatar: const Icon(Icons.map_outlined, size: 18),
                    label: Text(tr(context, 'Mappa', 'Map')),
                    onPressed: () => openMaps(r.addressOneLine!),
                  ),
                if (r.country == 'IT' && r.name != null)
                  ActionChip(
                    avatar: const Icon(Icons.phone_outlined, size: 18),
                    label: const Text('PagineBianche'),
                    onPressed: () => openPagineBianche(r.name!, r.addressOneLine ?? ''),
                  ),
                if (r.name != null)
                  ActionChip(
                    avatar: const Icon(Icons.travel_explore, size: 18),
                    label: Text(tr(context, 'Cerca sul web', 'Web search')),
                    onPressed: () => openWebSearch('${r.name} ${r.vat}'),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.share_outlined, size: 18),
                  label: Text(tr(context, 'Condividi', 'Share')),
                  onPressed: () => shareResult(context, r),
                ),
                ActionChip(
                  avatar: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(tr(context, 'Ricevuta PDF', 'PDF receipt')),
                  onPressed: () => shareReceiptPdf(context, r),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v, {String? copy}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(k,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: SelectableText(v)),
          if (copy != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: tr(context, 'Copia', 'Copy'),
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: copy));
                showSnack(context, tr(context, 'Copiato', 'Copied'));
              },
            ),
        ],
      ),
    );
  }
}

class _StreetView extends StatelessWidget {
  final String address;
  const _StreetView({required this.address});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: streetViewImage(address),
      builder: (context, snap) {
        if (snap.data == null) return const SizedBox.shrink();
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.memory(snap.data!, fit: BoxFit.cover),
        );
      },
    );
  }
}
