# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Pubblico generico: chiunque voglia sapere se una partita IVA esiste, se è valida
e a chi appartiene. Non si presuppone competenza fiscale: l'utente può non sapere
cosa sia VIES, un numero di consultazione o una cifra di controllo.

Gli usi più specialistici (verifica multipla, numero di consultazione, export CSV)
restano disponibili ma non sono il percorso principale.

## Product Purpose

Verificare in pochi secondi una partita IVA di qualunque paese UE (più l'Irlanda
del Nord) sul servizio ufficiale VIES della Commissione europea, e capire subito
l'esito: valida o no, denominazione, indirizzo. In più, controllare il codice
fiscale italiano.

Successo: l'utente ottiene una risposta chiara e affidabile senza dover conoscere
il funzionamento di VIES, e sa cosa fare quando la risposta non è "valida"
(numero errato, non iscritto a VIES, servizio nazionale giù).

## Positioning

Interroga direttamente la fonte ufficiale (API REST VIES), senza intermediari né
server propri: i dati arrivano dalla Commissione europea e restano sul telefono.
Prima della verifica online offre un controllo formale offline (formato e cifra
di controllo) per tutti gli Stati membri.

## Operating Context

- Uso da telefono (e tablet), spesso al volo: un numero letto su una fattura, un
  biglietto da visita, un sito o un messaggio.
- Input da tastiera, incolla, oppure foto con riconoscimento del testo (OCR sul
  dispositivo).
- Dopo l'esito: aprire la mappa, cercare il telefono (PagineBianche, solo IT),
  cercare sul web, condividere, salvare una ricevuta PDF.
- VIES dipende dai servizi nazionali, che possono essere temporaneamente non
  disponibili o limitare le richieste: lo stato "servizio non disponibile" è una
  situazione normale, non un'eccezione rara.

## Capabilities and Constraints

- Verifica VIES (GET; POST con P.IVA del richiedente per ottenere il numero di
  consultazione ufficiale).
- Controllo formale offline: cifra di controllo per 20 paesi, solo formato per
  ES, IE, CY, CZ, BG, LT, LV, XI.
- Codice fiscale italiano: verifica, omocodia, decodifica sesso/data/codice
  catastale (il nome del comune non è decodificato).
- Cronologia locale con ricerca, preferiti, export CSV; verifica multipla da
  elenco; ricevuta PDF.
- Anteprima Street View opzionale (chiave Google limitata all'app, letta da
  `.env` in build).
- Lingue: italiano e inglese.
- **Vincolo fisso: nessun server proprio.** Solo servizi ufficiali/pubblici e
  dati sul dispositivo; nessun account, nessuna raccolta dati.
- Identificativo Play Store `com.gdpitalia.VerificaPartitaIVA`, firmato con il
  keystore originale del 2018.
- Non deciso: modello economico (gratuità, pubblicità) e presenza del marchio
  dell'editore nell'interfaccia.
- Stack: Flutter (Material 3); iOS eventuale, con lo stesso aspetto Material.

## Brand Commitments

- Nome: "Partita IVA".
- **Vincolo fisso: l'icona storica — bandiera UE (blu, 12 stelle gialle) con
  fabbrica bianca — resta il segno riconoscibile dell'app.** Generatore
  vettoriale in `tool/make_icons.py`.

## Evidence on Hand

- Icona e grafiche Play Store: `assets/branding/`, `store/icon-512.png`,
  `store/feature-1024x500.png`.
- App pubblicata sul Play Store dal 2014 (v1 Delphi, ultima 1.2.2 del 2018).
- Non esistono recensioni, testimonianze, numeri di download o certificazioni
  da citare: non vanno inventati.
- L'app non è affiliata né approvata dalla Commissione europea: VIES è citato
  solo come fonte dei dati.

## Product Principles

1. **L'esito prima di tutto.** Valida / non valida / non verificabile deve essere
   leggibile in un colpo d'occhio, da chi non conosce il fisco.
2. **Spiegare, non solo segnalare.** Ogni esito negativo o errore dice perché e
   cosa fare dopo, in parole semplici.
3. **Fonte ufficiale, niente intermediari.** I dati vengono da VIES e restano sul
   dispositivo; nessuna funzione può richiedere un server proprio.
4. **Veloce al volo.** Il percorso digita/incolla/fotografa → verifica deve
   restare il più corto possibile; le funzioni avanzate non lo appesantiscono.
