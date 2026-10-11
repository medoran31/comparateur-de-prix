import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'resultats_page.dart';

class ParcourirPage extends StatefulWidget {
  const ParcourirPage({super.key});

  @override
  State<ParcourirPage> createState() => _ParcourirPageState();
}

class _ParcourirPageState extends State<ParcourirPage> {
  final supabase = Supabase.instance.client;

  bool _enChargement = true;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _sousCategories = [];
  List<Map<String, dynamic>> _produits = [];

  int? _categoryId;
  int? _subcategoryId;
  String? _unite;
  String? _marque;

  @override
  void initState() {
    super.initState();
    _chargerCategories();
  }

  Future<void> _chargerCategories() async {
    try {
      final reponse = await supabase
          .from('categories')
          .select('id, name_fr')
          .eq('active', true)
          .order('sort_order');

      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(reponse);
      });

      await _chargerProduits();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enChargement = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    }
  }

  Future<void> _chargerSousCategories() async {
    if (_categoryId == null) {
      setState(() {
        _sousCategories = [];
        _subcategoryId = null;
      });
      await _chargerProduits();
      return;
    }

    final reponse = await supabase
        .from('subcategories')
        .select('id, name_fr')
        .eq('category_id', _categoryId!)
        .eq('active', true)
        .order('sort_order');

    if (!mounted) return;
    setState(() {
      _sousCategories = List<Map<String, dynamic>>.from(reponse);
      _subcategoryId = null;
    });

    await _chargerProduits();
  }

  Future<void> _chargerProduits() async {
    setState(() {
      _enChargement = true;
    });

    try {
      var requete = supabase
          .from('products')
          .select('id, name_fr, name_ar, unit, brand')
          .eq('active', true);

      if (_categoryId != null) {
        requete = requete.eq('category_id', _categoryId!);
      }
      if (_subcategoryId != null) {
        requete = requete.eq('subcategory_id', _subcategoryId!);
      }

      final reponse = await requete.order('name_fr');

      if (!mounted) return;
      setState(() {
        _produits = List<Map<String, dynamic>>.from(reponse);
        _unite = null;
        _marque = null;
        _enChargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enChargement = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    }
  }

  List<String> get _unitesDisponibles {
    final ensemble = <String>{};
    for (final produit in _produits) {
      final unite = produit['unit']?.toString();
      if (unite != null && unite.isNotEmpty) ensemble.add(unite);
    }
    final liste = ensemble.toList();
    liste.sort();
    return liste;
  }

  List<String> get _marquesDisponibles {
    final ensemble = <String>{};
    for (final produit in _produits) {
      final marque = produit['brand']?.toString();
      if (marque != null && marque.isNotEmpty) ensemble.add(marque);
    }
    final liste = ensemble.toList();
    liste.sort();
    return liste;
  }

  List<Map<String, dynamic>> get _produitsFiltres {
    return _produits.where((produit) {
      if (_unite != null && produit['unit'] != _unite) return false;
      if (_marque != null && produit['brand'] != _marque) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Parcourir par categorie")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                DropdownButtonFormField<int?>(
                  value: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "Categorie",
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text("Toutes les categories",
                          overflow: TextOverflow.ellipsis),
                    ),
                    ..._categories.map((categorie) {
                      final id = (categorie['id'] as num).toInt();
                      return DropdownMenuItem<int?>(
                        value: id,
                        child: Text(categorie['name_fr'].toString(),
                            overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (value) async {
                    setState(() {
                      _categoryId = value;
                      _unite = null;
                      _marque = null;
                    });
                    await _chargerSousCategories();
                  },
                ),
                if (_categoryId != null) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    value: _sousCategories.any((s) =>
                    (s['id'] as num).toInt() == _subcategoryId)
                        ? _subcategoryId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Sous-categorie",
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text("Toutes les sous-categories",
                            overflow: TextOverflow.ellipsis),
                      ),
                      ..._sousCategories.map((s) {
                        final id = (s['id'] as num).toInt();
                        return DropdownMenuItem<int?>(
                          value: id,
                          child: Text(s['name_fr'].toString(),
                              overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (value) async {
                      setState(() {
                        _subcategoryId = value;
                        _unite = null;
                        _marque = null;
                      });
                      await _chargerProduits();
                    },
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _unitesDisponibles.contains(_unite)
                            ? _unite
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Unite",
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text("Toutes",
                                overflow: TextOverflow.ellipsis),
                          ),
                          ..._unitesDisponibles.map((unite) {
                            return DropdownMenuItem<String?>(
                              value: unite,
                              child: Text(unite,
                                  overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _unite = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _marquesDisponibles.contains(_marque)
                            ? _marque
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Marque",
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text("Toutes",
                                overflow: TextOverflow.ellipsis),
                          ),
                          ..._marquesDisponibles.map((marque) {
                            return DropdownMenuItem<String?>(
                              value: marque,
                              child: Text(marque,
                                  overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _marque = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _enChargement
                ? const Center(child: CircularProgressIndicator())
                : _produitsFiltres.isEmpty
                ? const Center(
              child: Text("Aucun produit trouve.",
                  style: TextStyle(color: Colors.grey)),
            )
                : ListView.builder(
              itemCount: _produitsFiltres.length,
              itemBuilder: (context, index) {
                final produit = _produitsFiltres[index];
                final marque = produit['brand']?.toString();
                var sousTitre = produit['unit'].toString();
                if (marque != null && marque.isNotEmpty) {
                  sousTitre = sousTitre + " • " + marque;
                }
                sousTitre = sousTitre +
                    " • " +
                    produit['name_ar'].toString();

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  child: ListTile(
                    title: Text(produit['name_fr']),
                    subtitle: Text(sousTitre),
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
    );
  }
}