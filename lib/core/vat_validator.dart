import 'countries.dart';

/// Esito del controllo formale (offline) di una partita IVA.
enum FormalCheck {
  /// Formato e cifra di controllo corretti.
  checksumOk,

  /// Formato corretto; per questo paese non verifichiamo la cifra di controllo.
  formatOk,

  /// Formato o cifra di controllo errati.
  invalid,
}

/// Rimuove spazi, punti, trattini e barre; porta in maiuscolo.
String cleanVat(String raw) =>
    raw.toUpperCase().replaceAll(RegExp(r'[\s.\-/]'), '');

/// Separa un eventuale prefisso paese ("IT0074...") dal numero.
/// Se il numero è già valido per [current] (es. chiave francese "SK..."),
/// non viene spezzato. Restituisce (paese o null, numero).
(Country?, String) splitVat(String raw, {Country? current}) {
  final v = cleanVat(raw);
  if (current != null && checkVat(current.code, v) != FormalCheck.invalid) {
    return (null, v);
  }
  if (v.length > 2 && RegExp(r'^[A-Z]{2}').hasMatch(v)) {
    final c = countryByCode(v.substring(0, 2));
    if (c != null) return (c, v.substring(2));
  }
  return (null, v);
}

List<int> _digits(String s) => s.codeUnits.map((c) => c - 48).toList();

bool _allDigits(String s) => RegExp(r'^\d+$').hasMatch(s);

FormalCheck checkVat(String countryCode, String rawNumber) {
  final n = cleanVat(rawNumber);
  bool fmt(String re) => RegExp('^$re\$').hasMatch(n);
  FormalCheck res(bool ok) => ok ? FormalCheck.checksumOk : FormalCheck.invalid;
  FormalCheck onlyFormat(String re) =>
      fmt(re) ? FormalCheck.formatOk : FormalCheck.invalid;

  switch (countryCode) {
    case 'IT':
      if (!fmt(r'\d{11}')) return FormalCheck.invalid;
      return res(_luhnIt(n));
    case 'AT':
      if (!fmt(r'U\d{8}')) return FormalCheck.invalid;
      final d = _digits(n.substring(1));
      var s = 0;
      for (var i = 0; i < 7; i++) {
        var p = d[i] * (i.isOdd ? 2 : 1);
        s += p > 9 ? p ~/ 10 + p % 10 : p;
      }
      return res((10 - (s + 4) % 10) % 10 == d[7]);
    case 'BE':
      var b = n;
      if (fmt(r'\d{9}')) b = '0$n';
      if (!RegExp(r'^[01]\d{9}$').hasMatch(b)) return FormalCheck.invalid;
      return res(97 - int.parse(b.substring(0, 8)) % 97 ==
          int.parse(b.substring(8)));
    case 'DE':
      if (!fmt(r'[1-9]\d{8}')) return FormalCheck.invalid;
      return res(_iso7064Mod1110(n));
    case 'HR':
      if (!fmt(r'\d{11}')) return FormalCheck.invalid;
      return res(_iso7064Mod1110(n));
    case 'DK':
      if (!fmt(r'[1-9]\d{7}')) return FormalCheck.invalid;
      return res(_weighted(n, [2, 7, 6, 5, 4, 3, 2, 1]) % 11 == 0);
    case 'EE':
      if (!fmt(r'10\d{7}')) return FormalCheck.invalid;
      final s = _weighted(n.substring(0, 8), [3, 7, 1, 3, 7, 1, 3, 7]);
      return res((10 - s % 10) % 10 == _digits(n)[8]);
    case 'EL':
      if (!fmt(r'\d{9}')) return FormalCheck.invalid;
      final d = _digits(n);
      var s = 0;
      for (var i = 0; i < 8; i++) {
        s += d[i] << (8 - i);
      }
      return res(s % 11 % 10 == d[8]);
    case 'FI':
      if (!fmt(r'\d{8}')) return FormalCheck.invalid;
      final r = _weighted(n.substring(0, 7), [7, 9, 10, 5, 8, 4, 2]) % 11;
      if (r == 1) return FormalCheck.invalid;
      return res((r == 0 ? 0 : 11 - r) == _digits(n)[7]);
    case 'FR':
      if (!fmt(r'[0-9A-HJ-NP-Z]{2}\d{9}')) return FormalCheck.invalid;
      final key = n.substring(0, 2);
      if (!_allDigits(key)) return FormalCheck.formatOk; // nuovo formato alfanumerico
      final siren = int.parse(n.substring(2));
      return res((12 + 3 * (siren % 97)) % 97 == int.parse(key));
    case 'HU':
      if (!fmt(r'\d{8}')) return FormalCheck.invalid;
      final s = _weighted(n.substring(0, 7), [9, 7, 3, 1, 9, 7, 3]);
      return res((10 - s % 10) % 10 == _digits(n)[7]);
    case 'LU':
      if (!fmt(r'\d{8}')) return FormalCheck.invalid;
      return res(
          int.parse(n.substring(0, 6)) % 89 == int.parse(n.substring(6)));
    case 'MT':
      if (!fmt(r'[1-9]\d{7}')) return FormalCheck.invalid;
      final s = _weighted(n.substring(0, 6), [3, 4, 6, 7, 8, 9]);
      return res(37 - s % 37 == int.parse(n.substring(6)));
    case 'NL':
      if (!fmt(r'\d{9}B\d{2}')) return FormalCheck.invalid;
      // Due algoritmi: "11-proef" (società) e mod 97 (ditte individuali dal 2020).
      final d = _digits(n.substring(0, 9));
      final s = _weighted(n.substring(0, 8), [9, 8, 7, 6, 5, 4, 3, 2]) - d[8];
      final elfProef = s % 11 == 0;
      return res(elfProef || _mod97('NL$n') == 1);
    case 'PL':
      if (!fmt(r'\d{10}')) return FormalCheck.invalid;
      final r = _weighted(n.substring(0, 9), [6, 5, 7, 2, 3, 4, 5, 6, 7]) % 11;
      return res(r != 10 && r == _digits(n)[9]);
    case 'PT':
      if (!fmt(r'[1-9]\d{8}')) return FormalCheck.invalid;
      var c = 11 - _weighted(n.substring(0, 8), [9, 8, 7, 6, 5, 4, 3, 2]) % 11;
      if (c > 9) c = 0;
      return res(c == _digits(n)[8]);
    case 'RO':
      if (!fmt(r'[1-9]\d{1,9}')) return FormalCheck.invalid;
      const w = [7, 5, 3, 2, 1, 7, 5, 3, 2];
      final body = n.substring(0, n.length - 1).padLeft(9, '0');
      final c = _weighted(body, w) * 10 % 11 % 10;
      return res(c == _digits(n).last);
    case 'SE':
      if (!fmt(r'\d{10}01')) return FormalCheck.invalid;
      return res(_luhn(n.substring(0, 10)));
    case 'SI':
      if (!fmt(r'[1-9]\d{7}')) return FormalCheck.invalid;
      var c = 11 - _weighted(n.substring(0, 7), [8, 7, 6, 5, 4, 3, 2]) % 11;
      if (c == 11) return FormalCheck.invalid;
      if (c == 10) c = 0;
      return res(c == _digits(n)[7]);
    case 'SK':
      if (!fmt(r'[1-9]\d{9}')) return FormalCheck.invalid;
      return res(BigInt.parse(n) % BigInt.from(11) == BigInt.zero);
    // Paesi per i quali controlliamo solo il formato.
    case 'BG':
      return onlyFormat(r'\d{9,10}');
    case 'CY':
      return onlyFormat(r'[0-59]\d{7}[A-Z]');
    case 'CZ':
      return onlyFormat(r'\d{8,10}');
    case 'ES':
      return onlyFormat(r'[A-Z0-9]\d{7}[A-Z0-9]');
    case 'IE':
      return onlyFormat(r'\d{7}[A-W][A-IW]?|\d[A-Z+*]\d{5}[A-W]');
    case 'LT':
      return onlyFormat(r'\d{9}|\d{12}');
    case 'LV':
      return onlyFormat(r'\d{11}');
    case 'XI':
      return onlyFormat(r'\d{9}|\d{12}|GD[0-4]\d{2}|HA[5-9]\d{2}');
  }
  return FormalCheck.invalid;
}

/// Algoritmo della partita IVA italiana (stesso del vecchio Controlla_Partita_iva).
bool _luhnIt(String n) {
  final d = _digits(n);
  var s = 0;
  for (var i = 0; i < 10; i++) {
    if (i.isEven) {
      s += d[i];
    } else {
      final p = d[i] * 2;
      s += p ~/ 10 + p % 10;
    }
  }
  return (10 - s % 10) % 10 == d[10];
}

bool _luhn(String n) {
  final d = _digits(n);
  var s = 0;
  for (var i = 0; i < d.length; i++) {
    var v = d[d.length - 1 - i];
    if (i.isOdd) {
      v *= 2;
      if (v > 9) v -= 9;
    }
    s += v;
  }
  return s % 10 == 0;
}

bool _iso7064Mod1110(String n) {
  final d = _digits(n);
  var p = 10;
  for (var i = 0; i < d.length - 1; i++) {
    var s = (d[i] + p) % 10;
    if (s == 0) s = 10;
    p = (2 * s) % 11;
  }
  var c = 11 - p;
  if (c == 10) c = 0;
  return c == d.last;
}

int _weighted(String n, List<int> w) {
  final d = _digits(n);
  var s = 0;
  for (var i = 0; i < w.length; i++) {
    s += d[i] * w[i];
  }
  return s;
}

/// Mod 97 su stringa alfanumerica (A=10 ... Z=35), come per l'IBAN.
int _mod97(String s) {
  final buf = StringBuffer();
  for (final c in s.codeUnits) {
    buf.write(c >= 65 ? c - 55 : c - 48);
  }
  return (BigInt.parse(buf.toString()) % BigInt.from(97)).toInt();
}
