import 'package:flutter/material.dart';

/// Blu bandiera UE: colore di partenza dello schema Material.
const euBlue = Color(0xFF003399);

/// Colori di esito che Material non prevede come ruoli (successo, avviso,
/// preferito). Definiti una volta per tema chiaro e scuro, con contrasto
/// AA verificato sulle superfici del tema (vedi test/theme_contrast_test.dart).
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  /// Testo e icone di esito positivo.
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;

  /// Testo e icone di avviso (servizio non disponibile, errore temporaneo).
  final Color warning;

  /// Stella dei preferiti.
  final Color favorite;

  const StatusColors({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.favorite,
  });

  static const light = StatusColors(
    success: Color(0xFF1B6B30),
    successContainer: Color(0xFFD3F0D8),
    onSuccessContainer: Color(0xFF0A3A17),
    warning: Color(0xFF8A4F00),
    favorite: Color(0xFF9A6700),
  );

  static const dark = StatusColors(
    success: Color(0xFF86D993),
    successContainer: Color(0xFF1D4B28),
    onSuccessContainer: Color(0xFFB9F2C2),
    warning: Color(0xFFFFB866),
    favorite: Color(0xFFFFCC33),
  );

  static StatusColors of(BuildContext context) =>
      Theme.of(context).extension<StatusColors>()!;

  @override
  StatusColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? favorite,
  }) => StatusColors(
    success: success ?? this.success,
    successContainer: successContainer ?? this.successContainer,
    onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    warning: warning ?? this.warning,
    favorite: favorite ?? this.favorite,
  );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      favorite: Color.lerp(favorite, other.favorite, t)!,
    );
  }
}

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: euBlue, brightness: b);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    extensions: [
      b == Brightness.light ? StatusColors.light : StatusColors.dark,
    ],
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
    // Animazione del gesto Indietro predittivo (Android 14+) tra le pagine.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      },
    ),
  );
}

/// Larghezza oltre la quale la navigazione passa alla barra laterale
/// (window size class "medium" di Material).
const mediumWidth = 600.0;

/// Larghezza oltre la quale le schermate usano due pannelli
/// (window size class "expanded").
const expandedWidth = 840.0;

/// Larghezza massima di lettura per le colonne singole.
const readableWidth = 720.0;

/// Centra il contenuto entro una larghezza leggibile, sui tablet.
class Readable extends StatelessWidget {
  final Widget child;
  const Readable({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: readableWidth),
      child: child,
    ),
  );
}
