import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import 'countries.dart';
import 'vies.dart';

/// Chiave Google opzionale per l'anteprima Street View.
/// Non è nel codice sorgente: si legge da app/.env in fase di build con
///   flutter run --dart-define-from-file=.env
/// La chiave va limitata all'app Android "com.gdpitalia.VerificaPartitaIVA"
/// (pacchetto + SHA-1): l'app invia entrambi negli header delle richieste.
const mapsApiKey = String.fromEnvironment('MAPS_API_KEY');
const _androidPackage = 'com.gdpitalia.VerificaPartitaIVA';
const _channel = MethodChannel('verifica_piva/app');

bool get streetViewEnabled => mapsApiKey.isNotEmpty;

Map<String, String>? _headersCache;

/// Header richiesti da Google per le chiavi limitate ad app Android.
/// La SHA-1 è letta dal certificato con cui è firmata l'app installata,
/// quindi è corretta sia in debug sia in release / Play App Signing.
Future<Map<String, String>> _mapsHeaders() async {
  if (_headersCache != null) return _headersCache!;
  final h = <String, String>{};
  if (!kIsWeb && Platform.isAndroid) {
    h['X-Android-Package'] = _androidPackage;
    try {
      final sha1 = await _channel.invokeMethod<String>('signingSha1');
      if (sha1 != null) h['X-Android-Cert'] = sha1;
    } catch (_) {}
  } else if (!kIsWeb && Platform.isIOS) {
    h['X-Ios-Bundle-Identifier'] = 'com.gdpitalia.verificaPiva';
  }
  return _headersCache = h;
}

final _svCache = <String, Uint8List?>{};

/// Scarica la foto Street View dell'indirizzo, o null se non disponibile.
/// Usa l'endpoint "metadata" (gratuito) per evitare l'immagine grigia vuota.
Future<Uint8List?> streetViewImage(String address) async {
  if (!streetViewEnabled) return null;
  if (_svCache.containsKey(address)) return _svCache[address];
  Uint8List? result;
  try {
    final headers = await _mapsHeaders();
    final loc = Uri.encodeQueryComponent(address);
    final meta = await http
        .get(
          Uri.parse('https://maps.googleapis.com/maps/api/streetview/metadata'
              '?location=$loc&source=outdoor&key=$mapsApiKey'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));
    if (jsonDecode(meta.body)['status'] == 'OK') {
      final img = await http
          .get(
            Uri.parse('https://maps.googleapis.com/maps/api/streetview'
                '?size=640x360&location=$loc&source=outdoor&key=$mapsApiKey'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));
      if (img.statusCode == 200) result = img.bodyBytes;
    }
  } catch (_) {}
  _svCache[address] = result;
  return result;
}

Future<void> _open(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

Future<void> openMaps(String address) => _open(
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeQueryComponent(address)}');

Future<void> openPagineBianche(String name, String address) => _open(
    'https://www.paginebianche.it/cerca?qs=${Uri.encodeQueryComponent(name)}'
    '&dv=${Uri.encodeQueryComponent(address)}');

Future<void> openWebSearch(String query) => _open(
    'https://www.google.com/search?q=${Uri.encodeQueryComponent(query)}');

String _fmtDate(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);

String resultText(BuildContext context, VatResult r) {
  final c = countryByCode(r.country);
  final b = StringBuffer()
    ..writeln('${c?.flag ?? ''} ${r.country} ${r.vat}')
    ..writeln(r.valid
        ? tr(context, '✅ Partita IVA valida (VIES)', '✅ Valid VAT number (VIES)')
        : tr(context, '❌ Partita IVA non valida (VIES)', '❌ Invalid VAT number (VIES)'));
  if (r.name != null) b.writeln(r.name);
  if (r.addressOneLine != null) b.writeln(r.addressOneLine);
  b.writeln('${tr(context, 'Verificata il', 'Checked on')} ${_fmtDate(r.date)}');
  if (r.consultation != null) {
    b.writeln('${tr(context, 'N. consultazione', 'Consultation no.')}: ${r.consultation}');
  }
  return b.toString().trim();
}

Future<void> shareResult(BuildContext context, VatResult r) async {
  final text = resultText(context, r);
  await SharePlus.instance.share(ShareParams(text: text));
}

/// Genera la ricevuta PDF della verifica.
Future<Uint8List> buildReceiptPdf(BuildContext context, VatResult r) async {
  final en = isEn(context);
  String t(String it, String e) => en ? e : it;

  pw.ThemeData theme;
  try {
    // Font Unicode (caratteri greci, polacchi, ecc.); serve la rete.
    theme = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.notoSansRegular(),
      bold: await PdfGoogleFonts.notoSansBold(),
    );
  } catch (_) {
    theme = pw.ThemeData.base();
  }

  final c = countryByCode(r.country);
  final doc = pw.Document(
    title: 'VIES ${r.country}${r.vat}',
    author: 'Partita IVA',
  );

  pw.Widget row(String label, String? value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 150,
              child: pw.Text(label,
                  style: const pw.TextStyle(color: PdfColors.grey700)),
            ),
            pw.Expanded(
              child: pw.Text(value ?? '—',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
      );

  doc.addPage(pw.Page(
    theme: theme,
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(48),
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(t('Verifica partita IVA comunitaria', 'EU VAT number check'),
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(
            t('Fonte: VIES – Commissione europea', 'Source: VIES – European Commission'),
            style: const pw.TextStyle(color: PdfColors.grey700)),
        pw.Divider(height: 32),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: r.valid ? PdfColors.green50 : PdfColors.red50,
            border: pw.Border.all(
                color: r.valid ? PdfColors.green700 : PdfColors.red700),
          ),
          child: pw.Text(
            r.valid
                ? t('PARTITA IVA VALIDA', 'VALID VAT NUMBER')
                : t('PARTITA IVA NON VALIDA', 'INVALID VAT NUMBER'),
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: r.valid ? PdfColors.green900 : PdfColors.red900,
            ),
          ),
        ),
        pw.SizedBox(height: 16),
        row(t('Stato membro', 'Member state'),
            '${r.country} – ${c?.name(en) ?? ''}'),
        row(t('Partita IVA', 'VAT number'), r.vat),
        row(t('Denominazione', 'Name'), r.name),
        row(t('Indirizzo', 'Address'), r.address?.trim()),
        row(t('Data e ora verifica', 'Date and time'), _fmtDate(r.date)),
        row(t('N. consultazione', 'Consultation number'), r.consultation),
        pw.Spacer(),
        pw.Text(
          r.consultation != null
              ? t(
                  'Il numero di consultazione è rilasciato da VIES e può essere usato per dimostrare alle autorità fiscali di aver verificato la partita IVA in questa data.',
                  'The consultation number is issued by VIES and can be used to prove to tax authorities that the VAT number was checked on this date.')
              : t(
                  'Per ottenere un numero di consultazione ufficiale, inserisci la tua partita IVA nelle impostazioni dell\'app.',
                  'To obtain an official consultation number, enter your own VAT number in the app settings.'),
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    ),
  ));
  return doc.save();
}

Future<void> shareReceiptPdf(BuildContext context, VatResult r) async {
  final bytes = await buildReceiptPdf(context, r);
  final stamp = DateFormat('yyyyMMdd_HHmm').format(r.date);
  await Printing.sharePdf(
      bytes: bytes, filename: 'VIES_${r.country}${r.vat}_$stamp.pdf');
}

/// Esporta righe CSV (separatore ";", compatibile con Excel italiano).
Future<void> shareCsv(String filename, List<List<String?>> rows) async {
  String esc(String? v) {
    final s = (v ?? '').replaceAll('\n', ' ').trim();
    return '"${s.replaceAll('"', '""')}"';
  }

  final csv = '﻿${rows.map((r) => r.map(esc).join(';')).join('\r\n')}';
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$filename');
  await f.writeAsString(csv, encoding: utf8);
  await SharePlus.instance
      .share(ShareParams(files: [XFile(f.path, mimeType: 'text/csv')]));
}
