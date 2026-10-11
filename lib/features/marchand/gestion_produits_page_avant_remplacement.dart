import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _enChargement = true;
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _chargerProduits();
  }

  // =========================================================
  // CHARGER LES PRODUITS
  // =========================================================

  Future<void> _chargerProduits() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Utilisateur non connecté.');
      }

      List<Map<String, dynamic>> resultats;

      if (widget.estAdmin) {
        final response = await supabase
            .from('products')
            .select()
            .order('name_fr');

        resultats = List<Map<String, dynamic>>.from(response);
      } else {
        final response = await supabase
            .from('products')
            .select()
            .eq('created_by', user.id)
            .order('name_fr');

        resultats = List<Map<String, dynamic>>.from(response);
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
        SnackBar(
          content: Text('Erreur de chargement : $e'),
        ),
      );
    }
  }

  // =========================================================
  // FILTRER LES PRODUITS
  // =========================================================

  List<Map<String, dynamic>> get _produitsFiltres {
    final texte = _recherche.trim().toLowerCase();

    if (texte.isEmpty) {
      return _produits;
    }

    return _produits.where((produit) {
      final nomFr =
      (produit['name_fr'] ?? '').toString().toLowerCase();

      final nomAr =
      (produit['name_ar'] ?? '').toString().toLowerCase();

      final categorie =
      (produit['category'] ?? '').toString().toLowerCase();

      return nomFr.contains(texte) ||
          nomAr.contains(texte) ||
          categorie.contains(texte);
    }).toList();
  }

  // =========================================================
  // FORMULAIRE AJOUT / MODIFICATION
  // =========================================================

  Future<void> _ouvrirFormulaire({
    Map<String, dynamic>? produit,
  }) async {
    final nomFrController = TextEditingController(
      text: produit?['name_fr']?.toString() ?? '',
    );

    final nomArController = TextEditingController(
      text: produit?['name_ar']?.toString() ?? '',
    );

    final categorieController = TextEditingController(
      text: produit?['category']?.toString() ?? 'alimentation',
    );

    final uniteController = TextEditingController(
      text: produit?['unit']?.toString() ?? '',
    );

    final estModification = produit != null;
    bool enregistrement = false;

    await showDialog(
      context: context,
      barrierDismissible: !enregistrement,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> enregistrer() async {
              final nomFr = nomFrController.text.trim();
              final nomAr = nomArController.text.trim();
              final categorie = categorieController.text.trim();
              final unite = uniteController.text.trim();

              if (nomFr.isEmpty ||
                  nomAr.isEmpty ||
                  categorie.isEmpty ||
                  unite.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Veuillez remplir tous les champs.',
                    ),
                  ),
                );
                return;
              }

              setDialogState(() {
                enregistrement = true;
              });

              try {
                // -------------------------------------------------
                // MODIFICATION
                // -------------------------------------------------

                if (estModification) {
                  await supabase.rpc(
                    'modifier_produit',
                    params: {
                      'p_product_id': produit['id'],
                      'p_name_fr': nomFr,
                      'p_name_ar': nomAr,
                      'p_category': categorie,
                      'p_unit': unite,
                    },
                  );
                }

                // -------------------------------------------------
                // AJOUT
                // -------------------------------------------------

                else {
                  await supabase.rpc(
                    'ajouter_produit',
                    params: {
                      'p_name_fr': nomFr,
                      'p_name_ar': nomAr,
                      'p_category': categorie,
                      'p_unit': unite,
                    },
                  );
                }

                if (!mounted) return;

                Navigator.of(dialogContext).pop();

                await _chargerProduits();

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      estModification
                          ? 'Produit modifié.'
                          : 'Produit ajouté.',
                    ),
                  ),
                );
              } catch (e) {
                setDialogState(() {
                  enregistrement = false;
                });

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      estModification
                          ? 'Impossible de modifier le produit : $e'
                          : 'Impossible d’ajouter le produit : $e',
                    ),
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(
                estModification
                    ? 'Modifier le produit'
                    : 'Nouveau produit',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ---------------------------------------------
                    // NOM FRANÇAIS
                    // ---------------------------------------------

                    TextField(
                      controller: nomFrController,
                      enabled: !enregistrement,
                      decoration: const InputDecoration(
                        labelText: 'Nom français',
                        hintText: 'Ex. Huile Elio',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ---------------------------------------------
                    // NOM ARABE
                    // ---------------------------------------------

                    TextField(
                      controller: nomArController,
                      enabled: !enregistrement,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        labelText: 'Nom arabe',
                        hintText: 'مثال: زيت إيليو',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ---------------------------------------------
                    // CATÉGORIE
                    // ---------------------------------------------

                    TextField(
                      controller: categorieController,
                      enabled: !enregistrement,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                        hintText: 'alimentation',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ---------------------------------------------
                    // UNITÉ
                    // ---------------------------------------------

                    TextField(
                      controller: uniteController,
                      enabled: !enregistrement,
                      decoration: const InputDecoration(
                        labelText: 'Unité',
                        hintText: '1 kg, 1 L, unité...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: enregistrement
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),

                ElevatedButton(
                  onPressed:
                  enregistrement ? null : enregistrer,
                  child: enregistrement
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    estModification
                        ? 'Enregistrer'
                        : 'Ajouter',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nomFrController.dispose();
    nomArController.dispose();
    categorieController.dispose();
    uniteController.dispose();
  }

  // =========================================================
  // SUPPRIMER UN PRODUIT
  // ADMIN UNIQUEMENT
  // =========================================================

  Future<void> _supprimerProduit(
      Map<String, dynamic> produit,
      ) async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Supprimer le produit ?',
          ),
          content: Text(
            'Voulez-vous vraiment supprimer '
                '"${produit['name_fr']}" ?\n\n'
                'Cette opération est réservée à '
                'l’administrateur.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () =>
                  Navigator.pop(context, true),
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
        params: {
          'p_product_id': produit['id'],
        },
      );

      await _chargerProduits();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produit supprimé.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de supprimer le produit : $e',
          ),
        ),
      );
    }
  }

  // =========================================================
  // INTERFACE
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final produits = _produitsFiltres;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.estAdmin
              ? 'Gestion du catalogue'
              : 'Mes produits',
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaire(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),

      body: _enChargement
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : Column(
        children: [
          // -------------------------------------------------
          // RECHERCHE
          // -------------------------------------------------

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

          // -------------------------------------------------
          // LISTE
          // -------------------------------------------------

          Expanded(
            child: produits.isEmpty
                ? Center(
              child: Text(
                widget.estAdmin
                    ? 'Aucun produit trouvé.'
                    : 'Vous n’avez encore ajouté '
                    'aucun produit.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            )
                : RefreshIndicator(
              onRefresh: _chargerProduits,
              child: ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  90,
                ),
                itemCount: produits.length,
                itemBuilder:
                    (context, index) {
                  final produit =
                  produits[index];

                  return Card(
                    child: ListTile(
                      leading:
                      const CircleAvatar(
                        child: Icon(
                          Icons
                              .inventory_2_outlined,
                        ),
                      ),

                      title: Text(
                        produit['name_fr']
                            ?.toString() ??
                            '',
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      subtitle: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          const SizedBox(
                            height: 4,
                          ),

                          Text(
                            produit['name_ar']
                                ?.toString() ??
                                '',
                            textDirection:
                            TextDirection
                                .rtl,
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          Text(
                            '${produit['category']}'
                                ' • '
                                '${produit['unit']}',
                          ),
                        ],
                      ),

                      isThreeLine: true,

                      trailing: Row(
                        mainAxisSize:
                        MainAxisSize.min,
                        children: [
                          // --------------------------------
                          // MODIFIER
                          // --------------------------------

                          IconButton(
                            tooltip: 'Modifier',
                            icon: const Icon(
                              Icons
                                  .edit_outlined,
                            ),
                            onPressed: () {
                              _ouvrirFormulaire(
                                produit:
                                produit,
                              );
                            },
                          ),

                          // --------------------------------
                          // SUPPRIMER
                          // ADMIN UNIQUEMENT
                          // --------------------------------

                          if (widget.estAdmin)
                            IconButton(
                              tooltip:
                              'Supprimer',
                              icon:
                              const Icon(
                                Icons
                                    .delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                _supprimerProduit(
                                  produit,
                                );
                              },
                            ),
                        ],
                      ),
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