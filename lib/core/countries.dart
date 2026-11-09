/// Stati membri interrogabili su VIES.
///
/// [code] è il codice usato da VIES (Grecia = EL, Irlanda del Nord = XI),
/// [iso] quello ISO 3166 usato per la bandiera.
class Country {
  final String code;
  final String iso;
  final String nameIt;
  final String nameEn;
  final String example;

  const Country(this.code, this.iso, this.nameIt, this.nameEn, this.example);

  String name(bool en) => en ? nameEn : nameIt;

  /// Bandiera emoji ricavata dal codice ISO.
  String get flag {
    if (iso == 'XI') return '🇬🇧';
    return String.fromCharCodes(
      iso.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41),
    );
  }
}

const countries = <Country>[
  Country('IT', 'IT', 'Italia', 'Italy', '00743110157'),
  Country('AT', 'AT', 'Austria', 'Austria', 'U12345678'),
  Country('BE', 'BE', 'Belgio', 'Belgium', '0123456789'),
  Country('BG', 'BG', 'Bulgaria', 'Bulgaria', '123456789'),
  Country('CY', 'CY', 'Cipro', 'Cyprus', '12345678X'),
  Country('HR', 'HR', 'Croazia', 'Croatia', '12345678901'),
  Country('DK', 'DK', 'Danimarca', 'Denmark', '12345678'),
  Country('EE', 'EE', 'Estonia', 'Estonia', '123456789'),
  Country('FI', 'FI', 'Finlandia', 'Finland', '12345678'),
  Country('FR', 'FR', 'Francia', 'France', 'XX123456789'),
  Country('DE', 'DE', 'Germania', 'Germany', '123456789'),
  Country('EL', 'GR', 'Grecia', 'Greece', '123456789'),
  Country('IE', 'IE', 'Irlanda', 'Ireland', '1234567WA'),
  Country('XI', 'XI', 'Irlanda del Nord', 'Northern Ireland', '123456789'),
  Country('LV', 'LV', 'Lettonia', 'Latvia', '12345678901'),
  Country('LT', 'LT', 'Lituania', 'Lithuania', '123456789'),
  Country('LU', 'LU', 'Lussemburgo', 'Luxembourg', '12345678'),
  Country('MT', 'MT', 'Malta', 'Malta', '12345678'),
  Country('NL', 'NL', 'Paesi Bassi', 'Netherlands', '123456789B01'),
  Country('PL', 'PL', 'Polonia', 'Poland', '1234567890'),
  Country('PT', 'PT', 'Portogallo', 'Portugal', '123456789'),
  Country('CZ', 'CZ', 'Rep. Ceca', 'Czechia', '12345678'),
  Country('RO', 'RO', 'Romania', 'Romania', '1234567890'),
  Country('SK', 'SK', 'Slovacchia', 'Slovakia', '1234567890'),
  Country('SI', 'SI', 'Slovenia', 'Slovenia', '12345678'),
  Country('ES', 'ES', 'Spagna', 'Spain', 'X1234567X'),
  Country('SE', 'SE', 'Svezia', 'Sweden', '123456789001'),
  Country('HU', 'HU', 'Ungheria', 'Hungary', '12345678'),
];

Country? countryByCode(String code) {
  final c = code.toUpperCase() == 'GR' ? 'EL' : code.toUpperCase();
  for (final x in countries) {
    if (x.code == c) return x;
  }
  return null;
}
