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

  /// true se formato e cifra di controllo sono corretti; false se il numero
  /// ha la forma giusta ma potrebbe essere stato letto male dalla foto.
  final bool checksumVerified;

  const OcrCandidate(
    this.kind,
    this.country,
    this.value,
    this.checksumVerified,
  );

  String get label => kind == CandidateKind.vat ? '$country $value' : value;

  @override
  bool operator ==(Object other) =>
      other is OcrCandidate &&
      other.kind == kind &&
      other.country == country &&
      other.value == value;

  @override
  int get hashCode => Object.hash(kind, country, value);
}

/// Esito della lettura di una foto: testo riconosciuto e candidati trovati.
class OcrResult {
  final String text;
  final List<OcrCandidate> candidates;
  const OcrResult(this.text, this.candidates);
}

/// Corregge gli scambi tipici dell'OCR dentro le sequenze numeriche:
/// O/D/Q→0, I/L/|→1, Z→2, S→5, B→8. Si applica solo ai "pezzi" che
/// contengono già almeno 6 cifre, per non toccare le parole normali.
String fixDigits(String token) {
  const map = {
    'O': '0', 'D': '0', 'Q': '0', 'I': '1', 'L': '1', '|': '1', //
    'Z': '2', 'S': '5', 'B': '8',
  };
  return token.split('').map((c) => map[c] ?? c).join();
}

/// Cerca partite IVA e codici fiscali in un testo (es. riconosciuto via OCR).
/// Prima i candidati con cifra di controllo corretta, poi quelli dubbi.
List<OcrCandidate> extractCandidates(String text) {
  final up = text.toUpperCase();
  // Unisce gruppi di cifre separati da spazi, punti o trattini: "007 431 10157".
  final joined = up.replaceAll(RegExp(r'(?<=\d)[ .\-](?=\d)'), '');
  // Versione con gli scambi OCR corretti nei pezzi a prevalenza numerica.
  final fixed = joined.replaceAllMapped(RegExp(r'[0-9OIL|ZSBDQ]{8,}'), (m) {
    final t = m.group(0)!;
    final digits = t.replaceAll(RegExp(r'\D'), '').length;
    return digits >= 6 ? fixDigits(t) : t;
  });

  final found = <OcrCandidate>{};
  final doubtful = <OcrCandidate>{};

  final codes = countries.map((c) => c.code).join('|');
  // Il codice paese può essere attaccato al testo prima ("P.IVAIT0074...").
  final prefixed = RegExp('($codes|GR)[ ]?([0-9][0-9A-Z+*]{7,11})(?![0-9A-Z])');

  for (final src in [up, joined, fixed]) {
    for (final m in prefixed.allMatches(src)) {
      final c = countryByCode(m.group(1)!)!;
      final n = m.group(2)!;
      final r = checkVat(c.code, n);
      if (r != FormalCheck.invalid) {
        found.add(
          OcrCandidate(
            CandidateKind.vat,
            c.code,
            n,
            r == FormalCheck.checksumOk,
          ),
        );
      }
    }
    // Partite IVA italiane senza prefisso: 11 cifre non attaccate ad altre cifre.
    for (final m in RegExp(r'(?<!\d)\d{11}(?!\d)').allMatches(src)) {
      final n = m.group(0)!;
      if (checkVat('IT', n) == FormalCheck.checksumOk) {
        found.add(OcrCandidate(CandidateKind.vat, 'IT', n, true));
      } else {
        doubtful.add(OcrCandidate(CandidateKind.vat, 'IT', n, false));
      }
    }
    for (final m in RegExp(
      r'[A-Z]{6}[0-9LMNPQRSTUV]{2}[ABCDEHLMPRST][0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{3}[A-Z]',
    ).allMatches(src)) {
      if (checkCodiceFiscale(m.group(0)!).valid) {
        found.add(
          OcrCandidate(CandidateKind.codiceFiscale, 'IT', m.group(0)!, true),
        );
      }
    }
  }

  final verified = found.where((c) => c.checksumVerified).toList();
  final rest = [
    ...found.where((c) => !c.checksumVerified),
    // I dubbi servono solo se non c'è niente di meglio.
    if (verified.isEmpty) ...doubtful.where((d) => !found.contains(d)),
  ];
  return [...verified, ...rest];
}

/// Scatta o sceglie una foto e la legge. Restituisce null se l'utente annulla.
Future<OcrResult?> scanImage(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 2400,
    imageQuality: 90,
  );
  if (file == null) return null;
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final res = await recognizer.processImage(
      InputImage.fromFilePath(file.path),
    );
    return OcrResult(res.text, extractCandidates(res.text));
  } finally {
    await recognizer.close();
  }
}
