import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// Cette fonction donne toujours le même identifiant pour ce téléphone.
// La première fois, elle en crée un nouveau et le garde en mémoire.
Future<String> obtenirIdAppareil() async {
  final prefs = await SharedPreferences.getInstance();
  String? id = prefs.getString('device_id');
  if (id == null) {
    id = const Uuid().v4();
    await prefs.setString('device_id', id);
  }
  return id;
}