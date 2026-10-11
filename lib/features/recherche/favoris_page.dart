import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/favoris.dart';
import 'fiche_marchand_page.dart';

class FavorisPage extends StatefulWidget {
  const FavorisPage({super.key});

  @override
  State<FavorisPage> createState() => _FavorisPageState();
}

class _FavorisPageState extends State<FavorisPage> {
  final supabase = Supabase.instance.client;
  bool _enChargement = true;
  List<Map<String, dynamic>> _marchands = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _enChargement = true;
    });
    final favoris = await obtenirFavoris();
    if (favoris.isEmpty) {
      setState(() {
        _marchands = [];
        _enChargement = false;
      });
      return;
    }
    try {
      final resultats = await supabase
          .from('merchants')
          .select('id, name, quarter')
          .inFilter('id', favoris.toList());
      setState(() {
        _marchands = List<Map<String, dynamic>>.from(resultats);
        _enChargement = false;
      });
    } catch (e) {
      setState(() {
        _enChargement = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mes favoris")),
      body: _enChargement
          ? const Center(child: CircularProgressIndicator())
          : _marchands.isEmpty
          ? const Center(child: Text("Vous n avez pas encore de commerce favori."))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _marchands.length,
        itemBuilder: (context, index) {
          final marchand = _marchands[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.favorite, color: Colors.red),
              title: Text(marchand['name']),
              subtitle: Text(marchand['quarter']),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FicheMarchandPage(
                      marchandId: marchand['id'],
                      marchandNom: marchand['name'],
                      quartier: marchand['quarter'],
                    ),
                  ),
                ).then((_) => _charger());
              },
            ),
          );
        },
      ),
    );
  }
}