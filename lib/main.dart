import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/store.dart';
import 'ui/home.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await Future.wait([
    initializeDateFormatting('it'),
    initializeDateFormatting('en'),
    store.load(),
  ]);
  runApp(PartitaIvaApp(store: store));
}

/// Rende disponibile [AppStore] a tutto l'albero dei widget.
/// Si ridisegnano solo i widget che lo leggono con [AppScope.of].
class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key, required AppStore store, required super.child})
    : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

final _light = buildTheme(Brightness.light);
final _dark = buildTheme(Brightness.dark);

class PartitaIvaApp extends StatelessWidget {
  final AppStore store;
  const PartitaIvaApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: store,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: store.themeNotifier,
        builder: (context, mode, child) => MaterialApp(
          title: 'Partita IVA',
          debugShowCheckedModeBanner: false,
          theme: _light,
          darkTheme: _dark,
          themeMode: mode,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('it'), Locale('en')],
          home: child,
        ),
        child: const HomeShell(),
      ),
    );
  }
}
