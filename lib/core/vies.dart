import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Risultato di una verifica VIES.
class VatResult {
  final String country;
  final String vat;
  final bool valid;
  final String? name;
  final String? address;
  final DateTime date;

  /// Numero di consultazione ufficiale (solo se si è indicata la propria P.IVA).
  final String? consultation;
  bool favorite;

  VatResult({
    required this.country,
    required this.vat,
    required this.valid,
    this.name,
    this.address,
    required this.date,
    this.consultation,
    this.favorite = false,
  });

  String get key => '$country$vat';

  /// Indirizzo su una sola riga (VIES usa "\n" come separatore).
  String? get addressOneLine => address
      ?.split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .join(', ');

  Map<String, dynamic> toJson() => {
        'c': country,
        'v': vat,
        'ok': valid,
        'n': name,
        'a': address,
        'd': date.toIso8601String(),
        'r': consultation,
        'f': favorite,
      };

  factory VatResult.fromJson(Map<String, dynamic> j) => VatResult(
        country: j['c'],
        vat: j['v'],
        valid: j['ok'],
        name: j['n'],
        address: j['a'],
        date: DateTime.parse(j['d']),
        consultation: j['r'],
        favorite: j['f'] ?? false,
      );
}

/// Errori restituiti da VIES, tradotti in un codice stabile per la UI.
class ViesException implements Exception {
  final String code;
  ViesException(this.code);

  /// true se ha senso riprovare più tardi.
  bool get transient => const {
        'SERVICE_UNAVAILABLE',
        'MS_UNAVAILABLE',
        'TIMEOUT',
        'MS_MAX_CONCURRENT_REQ',
        'GLOBAL_MAX_CONCURRENT_REQ',
        'NETWORK',
      }.contains(code);

  @override
  String toString() => 'ViesException($code)';
}

/// Client per l'API REST ufficiale VIES della Commissione europea.
/// Documentazione: https://ec.europa.eu/taxation_customs/vies/#/technical-information
class ViesClient {
  static const _base = 'https://ec.europa.eu/taxation_customs/vies/rest-api';
  final http.Client _http;

  ViesClient([http.Client? client]) : _http = client ?? http.Client();

  static String? _clean(dynamic v) {
    if (v is! String) return null;
    final t = v.trim();
    return (t.isEmpty || t == '---') ? null : t;
  }

  /// Verifica [vat] per il paese [country] (codice VIES, es. "IT", "EL").
  /// Se [requesterCountry] e [requesterVat] sono indicati, VIES restituisce
  /// anche il numero di consultazione.
  Future<VatResult> check(
    String country,
    String vat, {
    String? requesterCountry,
    String? requesterVat,
  }) async {
    final withRequester = (requesterVat ?? '').isNotEmpty;
    late http.Response resp;
    try {
      if (withRequester) {
        resp = await _http
            .post(
              Uri.parse('$_base/check-vat-number'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'countryCode': country,
                'vatNumber': vat,
                'requesterMemberStateCode': requesterCountry,
                'requesterNumber': requesterVat,
              }),
            )
            .timeout(const Duration(seconds: 30));
      } else {
        resp = await _http.get(
          Uri.parse('$_base/ms/$country/vat/${Uri.encodeComponent(vat)}'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 30));
      }
    } on TimeoutException {
      throw ViesException('TIMEOUT');
    } catch (_) {
      throw ViesException('NETWORK');
    }

    if (resp.statusCode >= 500) throw ViesException('SERVICE_UNAVAILABLE');

    final Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ViesException('SERVICE_UNAVAILABLE');
    }

    // Formato errore del POST: {"actionSucceed":false,"errorWrappers":[{"error":"..."}]}
    if (j['actionSucceed'] == false) {
      final errs = j['errorWrappers'];
      final code = (errs is List && errs.isNotEmpty)
          ? (errs.first['error'] ?? 'UNKNOWN')
          : 'UNKNOWN';
      throw ViesException(code);
    }

    // Il GET segnala gli errori in "userError" (VALID/INVALID sono esiti normali).
    final userError = j['userError'];
    if (userError is String &&
        userError != 'VALID' &&
        userError != 'INVALID') {
      throw ViesException(userError);
    }

    final valid = (j['valid'] ?? j['isValid']) == true;
    return VatResult(
      country: country,
      vat: vat,
      valid: valid,
      name: valid ? _clean(j['name']) : null,
      address: valid ? _clean(j['address']) : null,
      date: DateTime.tryParse(j['requestDate'] ?? '')?.toLocal() ??
          DateTime.now(),
      consultation: _clean(j['requestIdentifier']),
    );
  }

  /// Disponibilità dei servizi nazionali: mappa codice paese -> disponibile.
  Future<Map<String, bool>> status() async {
    try {
      final r = await _http
          .get(Uri.parse('$_base/check-status'))
          .timeout(const Duration(seconds: 15));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return {
        for (final c in (j['countries'] as List))
          c['countryCode'] as String: c['availability'] == 'Available',
      };
    } catch (_) {
      return {};
    }
  }
}
