import 'package:shared_preferences/shared_preferences.dart';

Future<Set<String>> obtenirFavoris() async {
  final prefs = await SharedPreferences.getInstance();
  final liste = prefs.getStringList('favoris_marchands') ?? [];
  return liste.toSet();
}

Future<void> ajouterFavori(String marchandId) async {
  final prefs = await SharedPreferences.getInstance();
  final liste = prefs.getStringList('favoris_marchands') ?? [];
  if (!liste.contains(marchandId)) {
    liste.add(marchandId);
    await prefs.setStringList('favoris_marchands', liste);
  }
}

Future<void> retirerFavori(String marchandId) async {
  final prefs = await SharedPreferences.getInstance();
  final liste = prefs.getStringList('favoris_marchands') ?? [];
  liste.remove(marchandId);
  await prefs.setStringList('favoris_marchands', liste);
}

Future<bool> estFavori(String marchandId) async {
  final favoris = await obtenirFavoris();
  return favoris.contains(marchandId);
}