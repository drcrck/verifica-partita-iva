import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'codice_fiscale.dart';
import 'countries.dart';
import 'vat_validator.dart';

enum CandidateKind { vat, codiceFiscale }

class OcrCandidate {
  final CandidateKind kind;
  final String country; // per le P.IVA
  final String value;
  final bool checksumVerified;

  const OcrCandidate(this.kind, this.country, this.value, this.checksumVerified);

  String get label =>
      kind == CandidateKind.vat ? '$country $value' : value;

  @override
  bool operator ==(Object other) =>
      other is OcrCandidate && other.kind == kind && other.country == country && other.value == value;

  @override
  int get hashCode => Object.hash(kind, country, value);
}

/// Cerca partite IVA e codici fiscali in un testo (es. riconosciuto via OCR).
/// I candidati con cifra di controllo verificata vengono per primi.
List<OcrCandidate> extractCandidates(String text) {
  final up = text.toUpperCase();
  // Unisce gruppi di cifre separati da spazi o punti: "007 431 10157".
  final joined = up.replaceAll(RegExp(r'(?<=\d)[ .](?=\d)'), '');
  final found = <OcrCandidate>{};

  final codes = countries.map((c) => c.code).join('|');
  final prefixed = RegExp('\\b($codes|GR)[ ]?([0-9A-Z+*]{8,12})\\b');
  for (final src in [up, joined]) {
    for (final m in prefixed.allMatches(src)) {
      final c = countryByCode(m.group(1)!)!;
      final n = m.group(2)!;
      final r = checkVat(c.code, n);
      if (r != FormalCheck.invalid) {
        found.add(OcrCandidate(
            CandidateKind.vat, c.code, n, r == FormalCheck.checksumOk));
      }
    }
    // Partite IVA italiane senza prefisso: 11 cifre con checksum corretto.
    for (final m in RegExp(r'(?<![0-9A-Z])\d{11}(?![0-9])').allMatches(src)) {
      final n = m.group(0)!;
      if (checkVat('IT', n) == FormalCheck.checksumOk) {
        found.add(OcrCandidate(CandidateKind.vat, 'IT', n, true));
      }
    }
    for (final m in RegExp(
            r'\b[A-Z]{6}[0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{3}[A-Z]\b')
        .allMatches(src)) {
      if (checkCodiceFiscale(m.group(0)!).valid) {
        found.add(OcrCandidate(CandidateKind.codiceFiscale, 'IT', m.group(0)!, true));
      }
    }
  }
  final list = found.toList()
    ..sort((a, b) => (b.checksumVerified ? 1 : 0) - (a.checksumVerified ? 1 : 0));
  return list;
}

/// Scatta o sceglie una foto e restituisce i candidati trovati.
/// Restituisce null se l'utente annulla.
Future<List<OcrCandidate>?> scanImage(ImageSource source) async {
  final file = await ImagePicker()
      .pickImage(source: source, maxWidth: 2400, imageQuality: 90);
  if (file == null) return null;
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final res = await recognizer.processImage(InputImage.fromFilePath(file.path));
    return extractCandidates(res.text);
  } finally {
    await recognizer.close();
  }
}
