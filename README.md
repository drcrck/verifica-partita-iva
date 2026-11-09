# Partita IVA 2.0 (Flutter)

Riscrittura completa (2026) dell'app Android pubblicata nel 2018 come `com.gdpitalia.VerificaPartitaIVA`.

## Funzioni
- Verifica P.IVA UE sull'API REST ufficiale **VIES** (niente più isvat.eu, che ha un limite di 100 richieste al mese)
- Numero di consultazione VIES se imposti la tua P.IVA nelle Impostazioni
- Ricevuta PDF, condivisione, mappa, PagineBianche, ricerca web
- Lettura della P.IVA da foto (OCR ML Kit, offline)
- Controllo formale offline (cifra di controllo per 20 paesi, solo formato per gli altri)
- Cronologia con ricerca, preferiti ed export CSV
- Verifica multipla da elenco con export CSV
- Codice fiscale: verifica, omocodia, decodifica di sesso, data e comune
- Tema chiaro/scuro, italiano/inglese, indicatore di disponibilità dei servizi nazionali

## Sviluppo
```
flutter pub get
flutter test
flutter run
```

## Release Play Store
1. Copia `android/key.properties.example` in `android/key.properties` e inserisci le password
   del keystore originale `C:\Progetti\firma_android.keystore` (alias `cert_gdp`).
2. Aumenta `version:` in `pubspec.yaml` (il numero dopo `+` è il versionCode, l'ultimo pubblicato è 9).
3. Compila:
   ```
   flutter build appbundle --release ^
     --dart-define-from-file=.env
   ```
   `.env` (vedi `.env.example`) contiene `MAPS_API_KEY`; senza, l'anteprima Street View è disattivata.
   La SHA-1 per gli header Google è letta a runtime dal certificato di firma.
