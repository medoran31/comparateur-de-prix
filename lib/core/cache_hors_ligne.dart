import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> sauvegarderCache(String cle, dynamic donnees) async {
  final prefs = await SharedPreferences.getInstance();
  final enveloppe = {
    'donnees': donnees,
    'date': DateTime.now().toIso8601String(),
  };
  await prefs.setString(cle, jsonEncode(enveloppe));
}

Future<Map<String, dynamic>?> lireCache(String cle) async {
  final prefs = await SharedPreferences.getInstance();
  final texte = prefs.getString(cle);
  if (texte == null) return null;
  try {
    return jsonDecode(texte) as Map<String, dynamic>;
  } catch (e) {
    return null;
  }
}

String texteDateCache(String dateIso) {
  final date = DateTime.parse(dateIso);
  final jour = date.day.toString().padLeft(2, '0');
  final mois = date.month.toString().padLeft(2, '0');
  final heure = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return jour + "/" + mois + " a " + heure + ":" + minute;
}