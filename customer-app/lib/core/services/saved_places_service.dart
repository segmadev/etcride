import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedPlace {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;

  const SavedPlace({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });

  Map<String, dynamic> toJson() => {
    'placeId': placeId,
    'mainText': mainText,
    'secondaryText': secondaryText,
    'fullText': fullText,
  };

  factory SavedPlace.fromJson(Map<String, dynamic> j) => SavedPlace(
    placeId: j['placeId'] as String? ?? '',
    mainText: j['mainText'] as String? ?? '',
    secondaryText: j['secondaryText'] as String? ?? '',
    fullText: j['fullText'] as String? ?? '',
  );
}

class SavedPlacesService {
  static const _key = 'saved_places';

  static Future<List<SavedPlace>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) {
      try { return SavedPlace.fromJson(jsonDecode(s) as Map<String, dynamic>); }
      catch (_) { return null; }
    }).whereType<SavedPlace>().toList();
  }

  static Future<bool> isSaved(String placeId) async {
    final all = await getAll();
    return all.any((p) => p.placeId == placeId);
  }

  static Future<void> save(SavedPlace place) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((s) {
      try { return (jsonDecode(s) as Map)['placeId'] == place.placeId; }
      catch (_) { return false; }
    });
    raw.insert(0, jsonEncode(place.toJson()));
    await prefs.setStringList(_key, raw);
  }

  static Future<void> remove(String placeId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((s) {
      try { return (jsonDecode(s) as Map)['placeId'] == placeId; }
      catch (_) { return false; }
    });
    await prefs.setStringList(_key, raw);
  }

  static Future<void> toggle(SavedPlace place) async {
    if (await isSaved(place.placeId)) {
      await remove(place.placeId);
    } else {
      await save(place);
    }
  }
}
