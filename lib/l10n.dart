import 'package:flutter/widgets.dart';

/// Localizzazione minimale IT/EN: italiano per l'Italia, inglese altrove.
bool isEn(BuildContext context) =>
    Localizations.localeOf(context).languageCode != 'it';

/// Restituisce la stringa nella lingua corrente.
String tr(BuildContext context, String it, String en) =>
    isEn(context) ? en : it;

/// Messaggio leggibile per un codice di errore VIES.
String viesErrorMessage(BuildContext context, String code, String country) {
  switch (code) {
    case 'NETWORK':
      return tr(context, 'Nessuna connessione a Internet.',
          'No Internet connection.');
    case 'TIMEOUT':
    case 'SERVICE_UNAVAILABLE':
      return tr(context, 'Il servizio VIES non risponde. Riprova più tardi.',
          'The VIES service is not responding. Try again later.');
    case 'MS_UNAVAILABLE':
      return tr(
          context,
          'Il servizio nazionale ($country) è momentaneamente non disponibile. Riprova più tardi.',
          'The national service ($country) is temporarily unavailable. Try again later.');
    case 'MS_MAX_CONCURRENT_REQ':
    case 'GLOBAL_MAX_CONCURRENT_REQ':
      return tr(context, 'Troppe richieste in corso su VIES. Riprova tra qualche secondo.',
          'Too many concurrent requests to VIES. Try again in a few seconds.');
    case 'INVALID_INPUT':
      return tr(context, 'Formato della partita IVA non valido.',
          'Invalid VAT number format.');
    case 'INVALID_REQUESTER_INFO':
      return tr(
          context,
          'La tua partita IVA indicata nelle Impostazioni non è valida: correggila o cancellala.',
          'The requester VAT number in Settings is invalid: fix or remove it.');
    case 'VAT_BLOCKED':
    case 'IP_BLOCKED':
      return tr(context, 'Richiesta bloccata da VIES.', 'Request blocked by VIES.');
  }
  return tr(context, 'Errore VIES ($code).', 'VIES error ($code).');
}
