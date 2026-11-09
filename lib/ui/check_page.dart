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
import 'theme.dart';
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
      if (mounted) {
        setState(() => _error = viesErrorMessage(context, e.code, country));
      }
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
              subtitle: Text(
                tr(
                  context,
                  'Fattura, biglietto da visita, scontrino…',
                  'Invoice, business card, receipt…',
                ),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                tr(context, 'Scegli dalla galleria', 'Pick from gallery'),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    OcrResult? res;
    try {
      res = await scanImage(source);
    } catch (e) {
      if (mounted) {
        showSnack(
          context,
          tr(
            context,
            'Lettura della foto non riuscita: $e',
            'Could not read the photo: $e',
          ),
        );
      }
      return;
    }
    if (res == null || !mounted) return;
    final vats = res.candidates
        .where((c) => c.kind == CandidateKind.vat)
        .toList();
    if (vats.isEmpty) {
      await _showRecognizedText(res.text);
      return;
    }
    OcrCandidate? pick = vats.first;
    // Si sceglie dall'elenco se ci sono più numeri o se l'unico è dubbio.
    if (vats.length > 1 || !vats.first.checksumVerified) {
      pick = await showDialog<OcrCandidate>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(tr(context, 'Partite IVA trovate', 'VAT numbers found')),
          children: [
            for (final v in vats)
              SimpleDialogOption(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                onPressed: () => Navigator.pop(context, v),
                child: Row(
                  children: [
                    Flag(countryByCode(v.country)?.flag ?? ''),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.label),
                          if (!v.checksumVerified)
                            Text(
                              tr(
                                context,
                                'Da controllare: potrebbe essere letta male',
                                'Check it: it may have been misread',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: StatusColors.of(context).warning,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (v.checksumVerified)
                      Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: StatusColors.of(context).success,
                        semanticLabel: tr(
                          context,
                          'cifra di controllo corretta',
                          'check digit correct',
                        ),
                      ),
                  ],
                ),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showRecognizedText(res!.text);
              },
              child: Text(
                tr(context, 'Mostra il testo letto', 'Show recognised text'),
              ),
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
    // Un numero dubbio va prima controllato dall'utente, non verificato subito.
    if (pick.checksumVerified) {
      _check();
    } else {
      _focus.requestFocus();
    }
  }

  /// Mostra il testo riconosciuto, selezionabile: l'utente può copiare
  /// il numero giusto anche quando la ricerca automatica non lo trova.
  Future<void> _showRecognizedText(String text) {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text(
                tr(
                  context,
                  'Nessuna partita IVA trovata',
                  'No VAT number found',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                text.trim().isEmpty
                    ? tr(
                        context,
                        'Nella foto non è stato riconosciuto alcun testo. Riprova con più luce, inquadrando da vicino il numero e tenendo il telefono fermo.',
                        'No text was recognised in the photo. Try again with more light, framing the number closely and holding the phone steady.',
                      )
                    : tr(
                        context,
                        'Questo è il testo letto dalla foto. Puoi selezionare e copiare il numero, poi incollarlo nel campo.',
                        'This is the text read from the photo. You can select and copy the number, then paste it into the field.',
                      ),
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              if (text.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(text.trim()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final country = countryByCode(_countryCode)!;
    final number = cleanVat(_ctrl.text);
    final st = StatusColors.of(context);
    final cs = Theme.of(context).colorScheme;

    final form = <Widget>[
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
                  tooltip: tr(context, 'Cancella', 'Clear'),
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
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.search),
        label: Text(tr(context, 'Verifica su VIES', 'Check on VIES')),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      if (_availability[country.code] == false) ...[
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.cloud_off, size: 18, color: st.warning),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tr(
                  context,
                  'Il servizio nazionale ${country.code} risulta al momento non disponibile: la verifica potrebbe non riuscire.',
                  'The ${country.code} national service is currently unavailable: the check may fail.',
                ),
                style: TextStyle(color: st.warning),
              ),
            ),
          ],
        ),
      ],
    ];

    final tip = store.requesterVat.isEmpty
        ? _Tip(
            icon: Icons.receipt_long_outlined,
            text: tr(
              context,
              'Suggerimento: inserisci la tua partita IVA nelle Impostazioni per ottenere il numero di consultazione ufficiale VIES, utile come prova della verifica.',
              'Tip: enter your own VAT number in Settings to get the official VIES consultation number, useful as proof of the check.',
            ),
          )
        : null;

    final outcome = <Widget>[
      if (_error != null)
        Card(
          color: cs.errorContainer,
          child: Semantics(
            liveRegion: true,
            child: ListTile(
              leading: const ExcludeSemantics(child: Icon(Icons.cloud_off)),
              title: Text(_error!),
              textColor: cs.onErrorContainer,
              iconColor: cs.onErrorContainer,
              trailing: IconButton(
                tooltip: tr(context, 'Riprova', 'Retry'),
                icon: const Icon(Icons.refresh),
                onPressed: _check,
              ),
            ),
          ),
        ),
      if (_result != null) ResultCard(result: _result!),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        // Tablet in orizzontale: modulo a sinistra, esito a destra.
        if (c.maxWidth >= expandedWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 400,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    ...form,
                    if (tip != null) ...[const SizedBox(height: 20), tip],
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: outcome.isEmpty
                    ? _EmptyOutcome(loading: _loading)
                    : ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: Column(children: outcome),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        }
        return Readable(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...form,
              const SizedBox(height: 20),
              ...outcome,
              if (outcome.isEmpty && !_loading && tip != null) tip,
            ],
          ),
        );
      },
    );
  }
}

/// Pannello destro vuoto (solo tablet in orizzontale).
class _EmptyOutcome extends StatelessWidget {
  final bool loading;
  const _EmptyOutcome({required this.loading});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.verified_outlined,
                      size: 64,
                      color: cs.outlineVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr(
                      context,
                      "L'esito della verifica comparirà qui.",
                      'The check result will appear here.',
                    ),
                    style: TextStyle(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
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
          Expanded(
            child: Text(text, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
