import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/countries.dart';
import '../core/ocr.dart';
import '../core/vat_validator.dart';
import '../core/vies.dart';
import '../l10n.dart';
import '../main.dart';
import 'result_card.dart';
import 'widgets.dart';

final vies = ViesClient();

class CheckPage extends StatefulWidget {
  const CheckPage({super.key});

  @override
  State<CheckPage> createState() => _CheckPageState();
}

class _CheckPageState extends State<CheckPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String? _country;
  bool _loading = false;
  VatResult? _result;
  String? _error;
  Map<String, bool> _availability = {};

  @override
  void initState() {
    super.initState();
    vies.status().then((s) {
      if (mounted) setState(() => _availability = s);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _countryCode => _country ?? AppScope.read(context).defaultCountry;

  /// Se l'utente incolla "IT00743110157", sposta il prefisso nel menu paese.
  void _normalizeInput() {
    final (c, n) = splitVat(_ctrl.text, current: countryByCode(_countryCode));
    if (c != null) {
      _country = c.code;
      _ctrl.text = n;
    }
  }

  Future<void> _check() async {
    _normalizeInput();
    final number = cleanVat(_ctrl.text);
    if (number.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    final store = AppScope.read(context);
    final country = _countryCode;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final r = await vies.check(
        country,
        number,
        requesterCountry: store.requesterCountry,
        requesterVat: store.requesterVat,
      );
      await store.addResult(r);
      if (mounted) setState(() => _result = r);
    } on ViesException catch (e) {
      if (mounted) setState(() => _error = viesErrorMessage(context, e.code, country));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scan() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(tr(context, 'Scatta una foto', 'Take a photo')),
              subtitle: Text(tr(context, 'Fattura, biglietto da visita, scontrino…',
                  'Invoice, business card, receipt…')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr(context, 'Scegli dalla galleria', 'Pick from gallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    List<OcrCandidate>? found;
    try {
      found = await scanImage(source);
    } catch (e) {
      if (mounted) showSnack(context, tr(context, 'Lettura non riuscita', 'Scan failed'));
      return;
    }
    if (found == null || !mounted) return;
    final vats = found.where((c) => c.kind == CandidateKind.vat).toList();
    if (vats.isEmpty) {
      showSnack(context,
          tr(context, 'Nessuna partita IVA trovata nell\'immagine', 'No VAT number found in the image'));
      return;
    }
    OcrCandidate? pick = vats.first;
    if (vats.length > 1) {
      pick = await showDialog<OcrCandidate>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(tr(context, 'Partite IVA trovate', 'VAT numbers found')),
          children: [
            for (final v in vats)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, v),
                child: Row(children: [
                  Text(countryByCode(v.country)?.flag ?? ''),
                  const SizedBox(width: 8),
                  Expanded(child: Text(v.label)),
                  if (v.checksumVerified)
                    const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                ]),
              ),
          ],
        ),
      );
    }
    if (pick == null) return;
    setState(() {
      _country = pick!.country;
      _ctrl.text = pick.value;
    });
    _check();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final country = countryByCode(_countryCode)!;
    final number = cleanVat(_ctrl.text);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CountryDropdown(
          value: country.code,
          availability: _availability,
          onChanged: (v) {
            setState(() => _country = v);
            _focus.requestFocus();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z .\-/+*]')),
          ],
          decoration: InputDecoration(
            labelText: tr(context, 'Partita IVA', 'VAT number'),
            hintText: country.example,
            prefixText: '${country.code} ',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_ctrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _ctrl.clear();
                      _result = null;
                      _error = null;
                    }),
                  ),
                IconButton(
                  tooltip: tr(context, 'Leggi da foto', 'Scan from photo'),
                  icon: const Icon(Icons.document_scanner_outlined),
                  onPressed: _scan,
                ),
              ],
            ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _check(),
        ),
        if (number.isNotEmpty) ...[
          const SizedBox(height: 8),
          FormalCheckHint(checkVat(country.code, number)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading || number.isEmpty ? null : _check,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.search),
          label: Text(tr(context, 'Verifica su VIES', 'Check on VIES')),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        if (_availability[country.code] == false) ...[
          const SizedBox(height: 12),
          Text(
            tr(context,
                'Il servizio nazionale ${country.code} risulta al momento non disponibile.',
                'The ${country.code} national service is currently unavailable.'),
            style: const TextStyle(color: Colors.orange),
          ),
        ],
        const SizedBox(height: 20),
        if (_error != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.cloud_off),
              title: Text(_error!),
              trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _check),
            ),
          ),
        if (_result != null) ResultCard(result: _result!),
        if (_result == null && _error == null && !_loading && store.requesterVat.isEmpty)
          _Tip(
            icon: Icons.receipt_long_outlined,
            text: tr(
                context,
                'Suggerimento: inserisci la tua partita IVA nelle Impostazioni per ottenere il numero di consultazione ufficiale VIES, utile come prova della verifica.',
                'Tip: enter your own VAT number in Settings to get the official VIES consultation number, useful as proof of the check.'),
          ),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: cs.onSurfaceVariant))),
        ],
      ),
    );
  }
}
