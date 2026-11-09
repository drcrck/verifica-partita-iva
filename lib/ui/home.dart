import 'package:flutter/material.dart';

import '../l10n.dart';
import 'batch_page.dart';
import 'cf_page.dart';
import 'check_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final titles = [
      tr(context, 'Verifica partita IVA', 'VAT number check'),
      tr(context, 'Cronologia', 'History'),
      tr(context, 'Verifica multipla', 'Bulk check'),
      tr(context, 'Codice fiscale', 'Italian tax code'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          IconButton(
            tooltip: tr(context, 'Impostazioni', 'Settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      // Su tablet il contenuto resta centrato e leggibile.
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: IndexedStack(
            index: _index,
            children: const [
              CheckPage(),
              HistoryPage(),
              BatchPage(),
              CodiceFiscalePage(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.verified_outlined),
            selectedIcon: const Icon(Icons.verified),
            label: tr(context, 'Verifica', 'Check'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: tr(context, 'Cronologia', 'History'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.playlist_add_check),
            label: tr(context, 'Multipla', 'Bulk'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.badge_outlined),
            selectedIcon: const Icon(Icons.badge),
            label: tr(context, 'Cod. fiscale', 'Tax code'),
          ),
        ],
      ),
    );
  }
}
