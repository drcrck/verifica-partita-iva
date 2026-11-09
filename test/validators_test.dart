import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:verifica_piva/core/codice_fiscale.dart';
import 'package:verifica_piva/core/ocr.dart';
import 'package:verifica_piva/core/vat_validator.dart';
import 'package:verifica_piva/core/vies.dart';

void main() {
  group('checkVat', () {
    // Tutte confermate VALID da VIES (novembre 2026).
    const validInVies = [
      'IT00743110157',
      'IT00488410010',
      'IT01114601006',
      'DE811907980',
      'DE129273398',
      'NL004495445B01',
      'NL808661863B01',
      'ATU33864707',
      'ATU14703908',
      'DK13585628',
      'FI20774740',
      'FI01120389',
      'PL5260250995',
      'PL7740001454',
      'PT500100144',
      'SE556012579001',
      'LU15027442',
      'SI50223054',
      'HU10773381',
      'EE100247019',
      'EL094014201',
      'HR33392005961',
      'RO1590082',
      'RO14399840',
      'SK2020317068',
      'FR40303265045',
      'BE0202239951',
    ];
    for (final v in validInVies) {
      test('$v ha checksum corretto', () {
        expect(
          checkVat(v.substring(0, 2), v.substring(2)),
          FormalCheck.checksumOk,
        );
      });
    }

    test('solo formato per i paesi senza checksum', () {
      expect(checkVat('ES', 'A28015865'), FormalCheck.formatOk);
      expect(checkVat('IE', '6388047V'), FormalCheck.formatOk);
      expect(checkVat('XI', '220430231'), FormalCheck.formatOk);
    });

    test('errori', () {
      expect(checkVat('IT', '00743110158'), FormalCheck.invalid);
      expect(checkVat('IT', '0074311015'), FormalCheck.invalid);
      expect(checkVat('DE', '811907981'), FormalCheck.invalid);
      expect(checkVat('UK', '123456789'), FormalCheck.invalid);
    });

    test('pulizia e prefisso', () {
      final (c, n) = splitVat(' it 007.431-10157 ');
      expect(c?.code, 'IT');
      expect(n, '00743110157');
      expect(splitVat('GR094014201').$1?.code, 'EL');
    });
  });

  group('codice fiscale', () {
    test('valido', () {
      final i = checkCodiceFiscale('RSSMRA85T10A562S');
      expect(i.valid, isTrue);
      expect(i.sex, 'M');
      expect(i.birthDate, DateTime(1985, 12, 10));
      expect(i.belfiore, 'A562');
    });
    test('femmina', () {
      final cf = 'RSSMRA85T50A562${cfCheckChar('RSSMRA85T50A562')}';
      final i = checkCodiceFiscale(cf);
      expect(i.valid, isTrue);
      expect(i.sex, 'F');
    });
    test('omocodia', () {
      const base = 'RSSMRA85T10A56N';
      final i = checkCodiceFiscale('$base${cfCheckChar(base)}');
      expect(i.valid, isTrue);
      expect(i.omocodia, isTrue);
      expect(i.belfiore, 'A562');
    });
    test('checksum errato', () {
      expect(checkCodiceFiscale('RSSMRA85T10A562X').error, 'checksum');
    });
  });

  group('estrazione OCR: casi difficili', () {
    List<String> labels(String t) =>
        extractCandidates(t).map((e) => e.label).toList();
    test('numero attaccato al testo', () {
      expect(labels('P.IVA00743110157'), contains('IT 00743110157'));
      expect(labels('P.IVAIT00743110157'), contains('IT 00743110157'));
    });
    test('scambi OCR: O al posto di 0, I al posto di 1', () {
      expect(labels('Partita IVA: OO7431IO157'), contains('IT 00743110157'));
      expect(labels('P. IVA 0074311O157'), contains('IT 00743110157'));
    });
    test('cifre separate da trattini o punti', () {
      expect(labels('P.IVA 007-431-10157'), contains('IT 00743110157'));
    });
    test("numero dubbio proposto se non c'è altro", () {
      final c = extractCandidates('P.IVA 00743110158');
      expect(c, hasLength(1));
      expect(c.first.checksumVerified, isFalse);
    });
    test("il dubbio non compare se c'è un numero verificato", () {
      final c = extractCandidates('P.IVA 00743110157 tel 04241234567');
      expect(c.every((e) => e.checksumVerified), isTrue);
    });
    test('telefono e CAP non diventano P.IVA verificate', () {
      expect(
        extractCandidates(
          'Tel 0424 123456 CAP 36022',
        ).where((e) => e.checksumVerified),
        isEmpty,
      );
    });
  });

  test('estrazione OCR', () {
    const text =
        'ROSSI SRL\nP.IVA: IT 007 431 10157\nC.F. RSSMRA85T10A562S\n'
        'Cliente: VAT DE811907980 - tel 0424 123456';
    final found = extractCandidates(text);
    final labels = found.map((e) => e.label).toSet();
    expect(
      labels,
      containsAll(['IT 00743110157', 'DE 811907980', 'RSSMRA85T10A562S']),
    );
  });

  group('ViesClient', () {
    test('GET valida', () async {
      final client = ViesClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'isValid': true,
              'requestDate': '2026-11-09T13:47:04.088Z',
              'userError': 'VALID',
              'name': 'MOTOROLA SOLUTIONS ITALIA SRL',
              'address': 'LARGO FRANCESCO RICHINI 6 \n20122 MILANO MI\n',
              'requestIdentifier': '',
            }),
            200,
          ),
        ),
      );
      final r = await client.check('IT', '00743110157');
      expect(r.valid, isTrue);
      expect(r.name, 'MOTOROLA SOLUTIONS ITALIA SRL');
      expect(r.addressOneLine, 'LARGO FRANCESCO RICHINI 6, 20122 MILANO MI');
      expect(r.consultation, isNull);
    });
    test('POST con numero di consultazione', () async {
      final client = ViesClient(
        MockClient((req) async {
          expect(req.method, 'POST');
          return http.Response(
            jsonEncode({
              'valid': true,
              'requestIdentifier': 'WAPIAAAAaHAk8oEi',
              'name': '---',
            }),
            200,
          );
        }),
      );
      final r = await client.check(
        'IT',
        '00743110157',
        requesterCountry: 'IT',
        requesterVat: '00743110157',
      );
      expect(r.consultation, 'WAPIAAAAaHAk8oEi');
      expect(r.name, isNull);
    });
    test('errori', () async {
      final busy = ViesClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'isValid': false, 'userError': 'MS_UNAVAILABLE'}),
            200,
          ),
        ),
      );
      expect(
        () => busy.check('IT', '1'),
        throwsA(
          isA<ViesException>().having((e) => e.code, 'code', 'MS_UNAVAILABLE'),
        ),
      );
      final req = ViesClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'actionSucceed': false,
              'errorWrappers': [
                {'error': 'INVALID_REQUESTER_INFO'},
              ],
            }),
            200,
          ),
        ),
      );
      expect(
        () => req.check('IT', '1', requesterCountry: 'IT', requesterVat: 'x'),
        throwsA(
          isA<ViesException>().having(
            (e) => e.code,
            'code',
            'INVALID_REQUESTER_INFO',
          ),
        ),
      );
    });
  });
}
