import 'package:flutter/material.dart';

import '../l10n.dart';
import 'batch_page.dart';
import 'cf_page.dart';
import 'check_page.dart';
import 'history_page.dart';
import 'settings_page.dart';
import 'theme.dart';

class _Dest {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String title;
  const _Dest(this.icon, this.selectedIcon, this.label, this.title);
}

/// Struttura principale. Navigazione secondo la window size class Material:
/// barra in basso su telefono, barra laterale (rail) da 600 dp in su.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  List<_Dest> _dests(BuildContext context) => [
    _Dest(
      Icons.verified_outlined,
      Icons.verified,
      tr(context, 'Verifica', 'Check'),
      tr(context, 'Verifica partita IVA', 'VAT number check'),
    ),
    _Dest(
      Icons.history,
      Icons.history,
      tr(context, 'Cronologia', 'History'),
      tr(context, 'Cronologia', 'History'),
    ),
    _Dest(
      Icons.playlist_add_check,
      Icons.playlist_add_check,
      tr(context, 'Multipla', 'Bulk'),
      tr(context, 'Verifica multipla', 'Bulk check'),
    ),
    _Dest(
      Icons.badge_outlined,
      Icons.badge,
      tr(context, 'Cod. fiscale', 'Tax code'),
      tr(context, 'Codice fiscale', 'Italian tax code'),
    ),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final dests = _dests(context);
    final wide = MediaQuery.sizeOf(context).width >= mediumWidth;

    final pages = IndexedStack(
      index: _index,
      children: const [
        CheckPage(),
        HistoryPage(),
        BatchPage(),
        CodiceFiscalePage(),
      ],
    );

    // Indietro da una scheda secondaria torna a "Verifica" invece di uscire.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(dests[_index].title),
          actions: [
            IconButton(
              tooltip: tr(context, 'Impostazioni', 'Settings'),
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
            ),
          ],
        ),
        body: wide
            ? Row(
                children: [
                  SafeArea(
                    right: false,
                    child: NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: _select,
                      labelType: NavigationRailLabelType.all,
                      groupAlignment: -1,
                      destinations: [
                        for (final d in dests)
                          NavigationRailDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selectedIcon),
                            label: Text(d.label),
                          ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: SafeArea(left: false, child: pages)),
                ],
              )
            : pages,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _select,
                destinations: [
                  for (final d in dests)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: d.label,
                    ),
                ],
              ),
      ),
    );
  }
}
