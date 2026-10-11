import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ajouter_produit_catalogue_page.dart';
import 'ajouter_produit_marchand_page.dart';
import 'modifier_produit_catalogue_page.dart';

class GestionProduitsPage extends StatefulWidget {
  final bool estAdmin;

  const GestionProduitsPage({
    super.key,
    required this.estAdmin,
  });

  @override
  State<GestionProduitsPage> createState() => _GestionProduitsPageState();
}

class _GestionProduitsPageState extends State<GestionProduitsPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _produits = [];
  List<Map<String, dynamic>> _categories = [];
  bool _enChargement = true;
  String? _marchandId;
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _chargerProduits();
  }

  Future<void> _chargerProduits() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Utilisateur non connecté.');
      }

      final categoriesResponse = await supabase
          .from('categories')
          .select('id,name_fr')
          .eq('active', true)
          .order('sort_order');

      _categories = List<Map<String, dynamic>>.from(categoriesResponse);

      List<Map<String, dynamic>> resultats;

      if (widget.estAdmin) {
        final response = await supabase
            .from('products')
            .select(
          'id,name_fr,name_ar,category_id,subcategory_id,unit,brand,options,active',
        )
            .eq('active', true)
            .order('name_fr');

        resultats = List<Map<String, dynamic>>.from(response);
      } else {
        final marchandResponse = await supabase
            .from('merchants')
            .select('id')
            .eq('user_id', user.id)
            .limit(1);

        if (marchandResponse.isEmpty) {
          throw Exception('Aucune fiche marchand trouvée pour ce compte.');
        }

        _marchandId = marchandResponse[0]['id'].toString();

        final relations = await supabase
            .from('merchant_products')
            .select('product_id,options,active')
            .eq('merchant_id', _marchandId!)
            .eq('active', true);

        final lignes = List<Map<String, dynamic>>.from(relations);

        if (lignes.isEmpty) {
          resultats = [];
        } else {
          final ids = lignes
              .map((ligne) => ligne['product_id'])
              .whereType<num>()
              .map((id) => id.toInt())
              .toList();

          final produitsResponse = await supabase
              .from('products')
              .select(
            'id,name_fr,name_ar,category_id,subcategory_id,unit,brand,options,active',
          )
              .inFilter('id', ids)
              .eq('active', true)
              .order('name_fr');

          final produits = List<Map<String, dynamic>>.from(produitsResponse);

          final optionsParProduit = <int, dynamic>{};

          for (final ligne in lignes) {
            optionsParProduit[(ligne['product_id'] as num).toInt()] =
                ligne['options'] ?? <String, dynamic>{};
          }

          resultats = produits.map((produit) {
            final id = (produit['id'] as num).toInt();

            return {
              ...produit,
              'merchant_options': optionsParProduit[id] ?? <String, dynamic>{},
            };
          }).toList();
        }
      }

      if (!mounted) return;

      setState(() {
        _produits = resultats;
        _enChargement = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _enChargement = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement : $e')),
      );
    }
  }

  String _nomCategorie(dynamic categoryId) {
    if (categoryId == null) return 'Catégorie inconnue';

    final id = categoryId is num
        ? categoryId.toInt()
        : int.tryParse(categoryId.toString());

    if (id == null) return 'Catégorie inconnue';

    for (final categorie in _categories) {
      if ((categorie['id'] as num).toInt() == id) {
        return categorie['name_fr'].toString();
      }
    }

    return 'Catégorie inconnue';
  }

  List<Map<String, dynamic>> get _produitsFiltres {
    final texte = _recherche.trim().toLowerCase();

    if (texte.isEmpty) {
      return _produits;
    }

    return _produits.where((produit) {
      final nomFr = (produit['name_fr'] ?? '').toString().toLowerCase();
      final nomAr = (produit['name_ar'] ?? '').toString().toLowerCase();
      final categorie = _nomCategorie(produit['category_id']).toLowerCase();

      return nomFr.contains(texte) ||
          nomAr.contains(texte) ||
          categorie.contains(texte);
    }).toList();
  }

  Future<void> _supprimerProduit(Map<String, dynamic> produit) async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer le produit ?'),
          content: Text(
            'Voulez-vous vraiment supprimer "${produit['name_fr']}" ?\n\n'
                'Cette opération est réservée à l\'administrateur.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmer != true) return;

    try {
      await supabase.rpc(
        'supprimer_produit',
        params: {'p_product_id': produit['id']},
      );

      await _chargerProduits();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produit supprimé.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de supprimer le produit : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final produits = _produitsFiltres;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.estAdmin ? 'Gestion du catalogue' : 'Mes produits'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (widget.estAdmin) {
            Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => const AjouterProduitCataloguePage(),
              ),
            ).then((ajoute) {
              if (ajoute == true && mounted) {
                _chargerProduits();
              }
            });
            return;
          }

          if (_marchandId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fiche marchand introuvable.')),
            );
            return;
          }

          Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AjouterProduitMarchandPage(merchantId: _marchandId!),
            ),
          ).then((ajoute) {
            if (ajoute == true && mounted) {
              _chargerProduits();
            }
          });
        },
        icon: const Icon(Icons.add),
        label: Text(widget.estAdmin ? 'Ajouter au catalogue' : 'Ajouter un produit'),
      ),
      body: _enChargement
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher un produit...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (texte) {
                setState(() {
                  _recherche = texte;
                });
              },
            ),
          ),
          Expanded(
            child: produits.isEmpty
                ? Center(
              child: Text(
                widget.estAdmin
                    ? 'Aucun produit trouvé.'
                    : 'Vous n\'avez encore ajouté aucun produit.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
                : RefreshIndicator(
              onRefresh: _chargerProduits,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                itemCount: produits.length,
                itemBuilder: (context, index) {
                  final produit = produits[index];
                  final marque = produit['brand']?.toString();

                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.inventory_2_outlined),
                      ),
                      title: Text(
                        produit['name_fr']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            produit['name_ar']?.toString() ?? '',
                            textDirection: TextDirection.rtl,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _nomCategorie(produit['category_id']) +
                                ' • ' +
                                (produit['unit']?.toString() ?? '') +
                                (marque != null && marque.isNotEmpty
                                    ? ' • ' + marque
                                    : ''),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: widget.estAdmin
                          ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: Color(0xFF1F3A5F)),
                            tooltip: 'Modifier',
                            onPressed: () {
                              Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ModifierProduitCataloguePage(
                                        produit: produit,
                                      ),
                                ),
                              ).then((modifie) {
                                if (modifie == true && mounted) {
                                  _chargerProduits();
                                }
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            tooltip: 'Supprimer',
                            onPressed: () => _supprimerProduit(produit),
                          ),
                        ],
                      )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}