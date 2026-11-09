import 'package:flutter/material.dart';

import '../core/actions.dart' show streetViewEnabled;
import '../core/vat_validator.dart';
import '../l10n.dart';
import '../main.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _vat = TextEditingController(
    text: AppScope.read(context).requesterVat,
  );
  late String _reqCountry = AppScope.read(context).requesterCountry;

  @override
  void dispose() {
    _vat.dispose();
    super.dispose();
  }

  void _saveRequester() {
    final n = cleanVat(_vat.text);
    if (n.isNotEmpty && checkVat(_reqCountry, n) == FormalCheck.invalid) {
      showSnack(
        context,
        tr(
          context,
          'La partita IVA non è formalmente corretta',
          'The VAT number is not formally correct',
        ),
      );
      return;
    }
    AppScope.read(context).setRequester(_reqCountry, n);
    FocusScope.of(context).unfocus();
    showSnack(context, tr(context, 'Salvato', 'Saved'));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final muted = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Impostazioni', 'Settings'))),
      body: Readable(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            SectionTitle(tr(context, 'Aspetto', 'Appearance')),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto),
                  label: Text(tr(context, 'Sistema', 'System')),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode),
                  label: Text(tr(context, 'Chiaro', 'Light')),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode),
                  label: Text(tr(context, 'Scuro', 'Dark')),
                ),
              ],
              selected: {store.themeMode},
              onSelectionChanged: (s) => store.setTheme(s.first),
            ),
            const SizedBox(height: 24),
            CountryDropdown(
              label: tr(context, 'Paese predefinito', 'Default country'),
              value: store.defaultCountry,
              onChanged: store.setDefaultCountry,
            ),
            const Divider(height: 40),
            SectionTitle(tr(context, 'La tua partita IVA', 'Your VAT number')),
            const SizedBox(height: 4),
            Text(
              tr(
                context,
                'Facoltativa. Se la indichi, VIES rilascia un numero di consultazione per ogni verifica: '
                    'è la prova ufficiale che hai controllato il cliente o fornitore in quella data '
                    '(utile per le operazioni intracomunitarie). Resta salvata solo su questo dispositivo.',
                'Optional. If set, VIES issues a consultation number for each check: '
                    'official proof that you verified the customer or supplier on that date. '
                    'It is stored on this device only.',
              ),
              style: muted,
            ),
            const SizedBox(height: 12),
            CountryDropdown(
              value: _reqCountry,
              onChanged: (v) => setState(() => _reqCountry = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vat,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: tr(context, 'Partita IVA', 'VAT number'),
                prefixText: '$_reqCountry ',
              ),
              onSubmitted: (_) => _saveRequester(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: _saveRequester,
                child: Text(tr(context, 'Salva', 'Save')),
              ),
            ),
            const Divider(height: 40),
            SectionTitle(tr(context, 'Informazioni', 'About')),
            const SizedBox(height: 8),
            Text(
              tr(
                context,
                'I dati provengono dal servizio ufficiale VIES della Commissione europea. '
                    'L\'app non ha server propri e non raccoglie dati personali: '
                    'cronologia e impostazioni restano sul dispositivo.',
                'Data comes from the official VIES service of the European Commission. '
                    'The app has no servers of its own and collects no personal data: '
                    'history and settings stay on the device.',
              ),
              style: muted,
            ),
            const SizedBox(height: 8),
            Text(
              streetViewEnabled
                  ? tr(
                      context,
                      'Anteprima Street View: attiva',
                      'Street View preview: enabled',
                    )
                  : tr(
                      context,
                      'Anteprima Street View: non configurata',
                      'Street View preview: not configured',
                    ),
              style: muted,
            ),
            const SizedBox(height: 8),
            Text('Partita IVA 2.0 · Diego Rigoni', style: muted),
          ],
        ),
      ),
    );
  }
}
