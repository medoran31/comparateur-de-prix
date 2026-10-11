import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'resultats_liste_page.dart';

class ListeCoursesPage extends StatefulWidget {
  const ListeCoursesPage({super.key});

  @override
  State<ListeCoursesPage> createState() => _ListeCoursesPageState();
}

class _ListeCoursesPageState extends State<ListeCoursesPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _controleur = TextEditingController();
  List<Map<String, dynamic>> _resultatsRecherche = [];
  bool _enChargement = false;
  final List<Map<String, dynamic>> _produitsSelectionnes = [];

  Future<void> _chercher(String texte) async {
    setState(() => _enChargement = true);
    try {
      final resultats = await supabase
          .from('products')
          .select()
          .or('name_fr.ilike.%$texte%,name_ar.ilike.%$texte%')
          .order('name_fr');
      setState(() {
        _resultatsRecherche = List<Map<String, dynamic>>.from(resultats);
        _enChargement = false;
      });
    } catch (e) {
      setState(() => _enChargement = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de recherche : $e')),
        );
      }
    }
  }

  void _ajouterProduit(Map<String, dynamic> produit) {
    final dejaPresent =
    _produitsSelectionnes.any((p) => p['id'] == produit['id']);
    if (dejaPresent) return;
    setState(() {
      _produitsSelectionnes.add(produit);
      _controleur.clear();
      _resultatsRecherche = [];
    });
  }

  void _retirerProduit(int id) {
    setState(() {
      _produitsSelectionnes.removeWhere((p) => p['id'] == id);
    });
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liste de courses')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controleur,
              decoration: const InputDecoration(
                hintText: 'Ajouter un produit (huile, semoule...)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (texte) {
                if (texte.length >= 2) {
                  _chercher(texte);
                } else {
                  setState(() => _resultatsRecherche = []);
                }
              },
            ),
            if (_enChargement)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_resultatsRecherche.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _resultatsRecherche.length,
                  itemBuilder: (context, index) {
                    final produit = _resultatsRecherche[index];
                    return ListTile(
                      title: Text(produit['name_fr']),
                      subtitle:
                      Text('${produit['unit']} • ${produit['name_ar']}'),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: () => _ajouterProduit(produit),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Votre liste (${_produitsSelectionnes.length})',
              style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _produitsSelectionnes.isEmpty
                  ? const Center(
                child: Text(
                  'Cherchez des produits ci-dessus et touchez-les pour les ajouter.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.builder(
                itemCount: _produitsSelectionnes.length,
                itemBuilder: (context, index) {
                  final produit = _produitsSelectionnes[index];
                  return Card(
                    child: ListTile(
                      title: Text(produit['name_fr']),
                      subtitle: Text(produit['unit']),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _retirerProduit(produit['id']),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _produitsSelectionnes.isEmpty
                  ? null
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultatsListePage(
                      produits: _produitsSelectionnes,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.compare_arrows),
              label: const Text('Comparer les prix'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}