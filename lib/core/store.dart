import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vies.dart';

/// Stato persistente dell'app: impostazioni e cronologia.
class AppStore extends ChangeNotifier {
  static const _kHistory = 'history';
  static const _kTheme = 'theme';
  static const _kReqCountry = 'reqCountry';
  static const _kReqVat = 'reqVat';
  static const _kDefCountry = 'defCountry';
  static const maxHistory = 300;

  late SharedPreferences _p;

  ThemeMode themeMode = ThemeMode.system;
  String requesterCountry = 'IT';
  String requesterVat = '';
  String defaultCountry = 'IT';
  List<VatResult> history = [];

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[_p.getInt(_kTheme) ?? 0];
    requesterCountry = _p.getString(_kReqCountry) ?? 'IT';
    requesterVat = _p.getString(_kReqVat) ?? '';
    defaultCountry = _p.getString(_kDefCountry) ?? 'IT';
    try {
      final raw = _p.getStringList(_kHistory) ?? [];
      history = raw.map((e) => VatResult.fromJson(jsonDecode(e))).toList();
    } catch (_) {
      history = [];
    }
  }

  Future<void> _saveHistory() =>
      _p.setStringList(_kHistory, history.map((e) => jsonEncode(e)).toList());

  /// Aggiunge in testa; se la stessa P.IVA esiste già, la sostituisce
  /// mantenendo lo stato di preferito.
  Future<void> addResult(VatResult r) async {
    final old = history.where((e) => e.key == r.key).toList();
    if (old.isNotEmpty) r.favorite = old.first.favorite;
    history.removeWhere((e) => e.key == r.key);
    history.insert(0, r);
    // Tronca, ma senza mai perdere i preferiti.
    while (history.length > maxHistory) {
      final i = history.lastIndexWhere((e) => !e.favorite);
      if (i < 0) break;
      history.removeAt(i);
    }
    notifyListeners();
    await _saveHistory();
  }

  bool isFavorite(String key) => history.any((e) => e.key == key && e.favorite);

  Future<void> toggleFavorite(String key) async {
    for (final e in history) {
      if (e.key == key) e.favorite = !e.favorite;
    }
    notifyListeners();
    await _saveHistory();
  }

  Future<void> remove(String key) async {
    history.removeWhere((e) => e.key == key);
    notifyListeners();
    await _saveHistory();
  }

  Future<void> clearHistory({bool keepFavorites = true}) async {
    history.removeWhere((e) => !keepFavorites || !e.favorite);
    notifyListeners();
    await _saveHistory();
  }

  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    await _p.setInt(_kTheme, m.index);
  }

  Future<void> setRequester(String country, String vat) async {
    requesterCountry = country;
    requesterVat = vat;
    notifyListeners();
    await _p.setString(_kReqCountry, country);
    await _p.setString(_kReqVat, vat);
  }

  Future<void> setDefaultCountry(String c) async {
    defaultCountry = c;
    notifyListeners();
    await _p.setString(_kDefCountry, c);
  }
}
