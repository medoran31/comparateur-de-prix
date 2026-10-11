import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'resultats_page.dart';
import 'parcourir_page.dart';
import '../../core/cache_hors_ligne.dart';

const String _cleCatalogue = 'catalogue_produits';

class RecherchePage extends StatefulWidget {
  const RecherchePage({super.key});

  @override
  State<RecherchePage> createState() => _RecherchePageState();
}

class _RecherchePageState extends State<RecherchePage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _controleur = TextEditingController();

  List<Map<String, dynamic>> _catalogue = [];
  List<Map<String, dynamic>> _resultats = [];
  bool _enChargement = true;
  bool _horsLigne = false;
  String? _dateCache;

  @override
  void initState() {
    super.initState();
    _chargerCatalogue();
  }

  Future<void> _chargerCatalogue() async {
    setState(() {
      _enChargement = true;
    });
    try {
      final reponse = await supabase
          .from('products')
          .select('id, name_fr, name_ar, unit')
          .eq('active', true)
          .order('name_fr');

      final liste = List<Map<String, dynamic>>.from(reponse);

      await sauvegarderCache(_cleCatalogue, liste);

      if (!mounted) return;
      setState(() {
        _catalogue = liste;
        _horsLigne = false;
        _dateCache = null;
        _enChargement = false;
      });
    } catch (e) {
      final cache = await lireCache(_cleCatalogue);

      if (!mounted) return;

      if (cache != null) {
        final liste = List<Map<String, dynamic>>.from(cache['donnees']);
        setState(() {
          _catalogue = liste;
          _horsLigne = true;
          _dateCache = cache['date'];
          _enChargement = false;
        });
      } else {
        setState(() {
          _enChargement = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Impossible de charger les produits.")),
          );
        }
      }
    }
  }

  void _chercher(String texte) {
    final recherche = texte.trim().toLowerCase();
    if (recherche.isEmpty) {
      setState(() => _resultats = []);
      return;
    }
    final liste = _catalogue.where((produit) {
      final nomFr = (produit['name_fr'] ?? '').toString().toLowerCase();
      final nomAr = (produit['name_ar'] ?? '').toString().toLowerCase();
      return nomFr.contains(recherche) || nomAr.contains(recherche);
    }).toList();
    setState(() => _resultats = liste);
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechercher un produit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: "Parcourir par categorie",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ParcourirPage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_horsLigne)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, size: 18, color: Color(0xFF856404)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Hors ligne - produits du " +
                            (_dateCache != null ? texteDateCache(_dateCache!) : ""),
                        style: const TextStyle(color: Color(0xFF856404), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _controleur,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Huile, semoule, tomates... (arabe ou français)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _chercher,
            ),
            const SizedBox(height: 16),
            if (_enChargement) const Center(child: CircularProgressIndicator()),
            if (!_enChargement)
              Expanded(
                child: _resultats.isEmpty && _controleur.text.trim().length >= 2
                    ? const Center(
                  child: Text('Aucun produit trouvé.', style: TextStyle(color: Colors.grey)),
                )
                    : ListView.builder(
                  itemCount: _resultats.length,
                  itemBuilder: (context, index) {
                    final produit = _resultats[index];
                    return Card(
                      child: ListTile(
                        title: Text(produit['name_fr']),
                        subtitle: Text('${produit['unit']} • ${produit['name_ar']}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ResultatsPage(
                                produitId: produit['id'],
                                produitNom: produit['name_fr'],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}