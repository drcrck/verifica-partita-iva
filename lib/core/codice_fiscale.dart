/// Verifica e decodifica del codice fiscale italiano (persone fisiche),
/// incluse le varianti per omocodia.
class CodiceFiscaleInfo {
  final bool valid;
  final String? error;
  final String? sex; // 'M' / 'F'
  final DateTime? birthDate;
  final String? belfiore; // codice catastale del comune o Z... per stato estero
  final bool omocodia;

  const CodiceFiscaleInfo({
    required this.valid,
    this.error,
    this.sex,
    this.birthDate,
    this.belfiore,
    this.omocodia = false,
  });

  bool get bornAbroad => belfiore?.startsWith('Z') ?? false;
}

const _odd = {
  '0': 1, '1': 0, '2': 5, '3': 7, '4': 9, '5': 13, '6': 15, '7': 17, //
  '8': 19, '9': 21, 'A': 1, 'B': 0, 'C': 5, 'D': 7, 'E': 9, 'F': 13,
  'G': 15, 'H': 17, 'I': 19, 'J': 21, 'K': 2, 'L': 4, 'M': 18, 'N': 20,
  'O': 11, 'P': 3, 'Q': 6, 'R': 8, 'S': 12, 'T': 14, 'U': 16, 'V': 10,
  'W': 22, 'X': 25, 'Y': 24, 'Z': 23,
};

const _months = 'ABCDEHLMPRST';
const _omocodici = 'LMNPQRSTUV'; // 0..9
const _numericPositions = [6, 7, 9, 10, 12, 13, 14];

int _evenValue(String c) {
  final u = c.codeUnitAt(0);
  return u <= 57 ? u - 48 : u - 65;
}

/// Calcola il carattere di controllo sui primi 15 caratteri.
String cfCheckChar(String first15) {
  var s = 0;
  for (var i = 0; i < 15; i++) {
    final c = first15[i];
    // posizioni 1,3,5... (1-based dispari) = indici pari
    s += i.isEven ? _odd[c]! : _evenValue(c);
  }
  return String.fromCharCode(65 + s % 26);
}

CodiceFiscaleInfo checkCodiceFiscale(String raw) {
  final cf = raw.toUpperCase().replaceAll(RegExp(r'\s'), '');
  if (cf.length != 16) {
    return const CodiceFiscaleInfo(valid: false, error: 'length');
  }
  final pattern = RegExp(
    r'^[A-Z]{6}[0-9LMNPQRSTUV]{2}[ABCDEHLMPRST][0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{3}[A-Z]$',
  );
  if (!pattern.hasMatch(cf)) {
    return const CodiceFiscaleInfo(valid: false, error: 'format');
  }
  if (cfCheckChar(cf.substring(0, 15)) != cf[15]) {
    return const CodiceFiscaleInfo(valid: false, error: 'checksum');
  }

  // Normalizza le cifre sostituite per omocodia.
  final chars = cf.split('');
  var omocodia = false;
  for (final p in _numericPositions) {
    final idx = _omocodici.indexOf(chars[p]);
    if (idx >= 0) {
      chars[p] = '$idx';
      omocodia = true;
    }
  }
  final norm = chars.join();

  final yy = int.parse(norm.substring(6, 8));
  final month = _months.indexOf(norm[8]) + 1;
  var day = int.parse(norm.substring(9, 11));
  final sex = day > 40 ? 'F' : 'M';
  if (day > 40) day -= 40;

  final nowYY = DateTime.now().year % 100;
  final year = (yy > nowYY ? 1900 : 2000) + yy;
  final date = DateTime(year, month, day);
  if (day < 1 || date.month != month) {
    return const CodiceFiscaleInfo(valid: false, error: 'date');
  }

  return CodiceFiscaleInfo(
    valid: true,
    sex: sex,
    birthDate: date,
    belfiore: norm.substring(11, 15),
    omocodia: omocodia,
  );
}
