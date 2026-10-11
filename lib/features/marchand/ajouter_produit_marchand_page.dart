import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AjouterProduitMarchandPage extends StatefulWidget {
  final String merchantId;

  const AjouterProduitMarchandPage({
    super.key,
    required this.merchantId,
  });

  @override
  State<AjouterProduitMarchandPage> createState() =>
      _AjouterProduitMarchandPageState();
}

class _AjouterProduitMarchandPageState
    extends State<AjouterProduitMarchandPage> {
  final supabase = Supabase.instance.client;

  bool _chargement = true;
  bool _enregistrement = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _sousCategories = [];
  List<Map<String, dynamic>> _produits = [];
  List<Map<String, dynamic>> _options = [];

  int? _categoryId;
  int? _subcategoryId;
  int? _productId;

  final Map<int, dynamic> _valeursOptions = {};

  @override
  void initState() {
    super.initState();
    _chargerCategories();
  }

  Future<void> _chargerCategories() async {
    try {
      final response = await supabase
          .from('categories')
          .select('id,name_fr,name_ar,sort_order,active')
          .eq('active', true)
          .order('sort_order');

      if (!mounted) return;

      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _chargement = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  Future<void> _chargerSousCategories() async {
    if (_categoryId == null) return;

    final response = await supabase
        .from('subcategories')
        .select('id,category_id,name_fr,name_ar,sort_order,active')
        .eq('category_id', _categoryId!)
        .eq('active', true)
        .order('sort_order');

    if (!mounted) return;

    setState(() {
      _sousCategories = List<Map<String, dynamic>>.from(response);
      _subcategoryId = null;
      _productId = null;
      _produits = [];
      _options = [];
      _valeursOptions.clear();
    });

    await _chargerProduits();
  }

  Future<void> _chargerProduits() async {
    if (_categoryId == null) return;

    final response = await supabase
        .from('products')
        .select(
          'id,name_fr,name_ar,category_id,subcategory_id,unit,active',
        )
        .eq('category_id', _categoryId!)
        .eq('active', true)
        .order('name_fr');

    var produits = List<Map<String, dynamic>>.from(response);

    if (_subcategoryId != null) {
      produits = produits.where((produit) {
        final id = produit['subcategory_id'];
        return id != null && (id as num).toInt() == _subcategoryId;
      }).toList();
    }

    if (!mounted) return;

    setState(() {
      _produits = produits;
      _productId = null;
      _options = [];
      _valeursOptions.clear();
    });
  }

  Future<void> _chargerOptions() async {
    if (_categoryId == null || _productId == null) return;

    final response = await supabase
        .from('category_options')
        .select(
          'id,category_id,subcategory_id,name_fr,name_ar,'
          'option_type,options,required,sort_order,active',
        )
        .eq('category_id', _categoryId!)
        .eq('active', true)
        .order('sort_order');

    final toutes = List<Map<String, dynamic>>.from(response);

    final options = toutes.where((option) {
      final subcategoryId = option['subcategory_id'];
      return subcategoryId == null ||
          (_subcategoryId != null &&
              (subcategoryId as num).toInt() == _subcategoryId);
    }).toList();

    if (!mounted) return;

    setState(() {
      _options = options;
      _valeursOptions.clear();

      for (final option in options) {
        final id = (option['id'] as num).toInt();
        final type = option['option_type'].toString();

        if (type == 'boolean') {
          _valeursOptions[id] = false;
        } else if (type == 'select') {
          final choix = _listeOptions(option['options']);
          _valeursOptions[id] = choix.isEmpty ? null : choix.first;
        } else {
          _valeursOptions[id] = '';
        }
      }
    });
  }

  List<String> _listeOptions(dynamic valeur) {
    if (valeur is List) {
      return valeur.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<void> _enregistrer() async {
    if (_productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un produit.')),
      );
      return;
    }

    for (final option in _options) {
      if (option['required'] != true) continue;

      final id = (option['id'] as num).toInt();
      final type = option['option_type'].toString();
      final valeur = _valeursOptions[id];

      if (type == 'text' &&
          (valeur == null || valeur.toString().trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Le champ "${option['name_fr']}" est obligatoire.',
            ),
          ),
        );
        return;
      }

      if (type == 'select' && valeur == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Le champ "${option['name_fr']}" est obligatoire.',
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _enregistrement = true;
    });

    try {
      final optionsJson = <String, dynamic>{};

      for (final option in _options) {
        final id = (option['id'] as num).toInt();
        final valeur = _valeursOptions[id];

        if (valeur == null) continue;
        if (valeur is String && valeur.trim().isEmpty) continue;

        optionsJson[id.toString()] = valeur;
      }

      final existant = await supabase
          .from('merchant_products')
          .select('product_id')
          .eq('merchant_id', widget.merchantId)
          .eq('product_id', _productId!)
          .limit(1);

      if (existant.isEmpty) {
        await supabase.from('merchant_products').insert({
          'merchant_id': widget.merchantId,
          'product_id': _productId,
          'options': optionsJson,
          'active': true,
        });
      } else {
        await supabase
            .from('merchant_products')
            .update({
          'options': optionsJson,
          'active': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
            .eq('merchant_id', widget.merchantId)
            .eq('product_id', _productId!);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produit ajouté à vos produits.'),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _enregistrement = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d’enregistrer le produit : $e'),
        ),
      );
    }
  }

  Widget _champOption(Map<String, dynamic> option) {
    final id = (option['id'] as num).toInt();
    final nom = option['name_fr'].toString();
    final type = option['option_type'].toString();
    final obligatoire = option['required'] == true;

    if (type == 'boolean') {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(obligatoire ? '$nom *' : nom),
        value: _valeursOptions[id] == true,
        onChanged: _enregistrement
            ? null
            : (value) {
                setState(() {
                  _valeursOptions[id] = value;
                });
              },
      );
    }

    if (type == 'select') {
      final choix = _listeOptions(option['options']);
      final valeur = _valeursOptions[id];

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          value: choix.contains(valeur) ? valeur : null,
          decoration: InputDecoration(
            labelText: obligatoire ? '$nom *' : nom,
            border: const OutlineInputBorder(),
          ),
          items: choix
              .map(
                (choix) => DropdownMenuItem<String>(
                  value: choix,
                  child: Text(choix),
                ),
              )
              .toList(),
          onChanged: _enregistrement
              ? null
              : (value) {
                  setState(() {
                    _valeursOptions[id] = value;
                  });
                },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: _valeursOptions[id]?.toString() ?? '',
        enabled: !_enregistrement,
        decoration: InputDecoration(
          labelText: obligatoire ? '$nom *' : nom,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) {
          _valeursOptions[id] = value;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ajouter un produit'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un produit'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            value: _categoryId,
            decoration: const InputDecoration(
              labelText: 'Catégorie',
              border: OutlineInputBorder(),
            ),
            items: _categories.map((categorie) {
              final id = (categorie['id'] as num).toInt();

              return DropdownMenuItem<int>(
                value: id,
                child: Text(categorie['name_fr'].toString()),
              );
            }).toList(),
            onChanged: _enregistrement
                ? null
                : (value) async {
                    setState(() {
                      _categoryId = value;
                    });

                    if (value != null) {
                      await _chargerSousCategories();
                    }
                  },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            value: _sousCategories.any(
              (sousCategorie) =>
                  (sousCategorie['id'] as num).toInt() == _subcategoryId,
            )
                ? _subcategoryId
                : null,
            decoration: const InputDecoration(
              labelText: 'Sous-catégorie',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Toutes les sous-catégories'),
              ),
              ..._sousCategories.map((sousCategorie) {
                final id = (sousCategorie['id'] as num).toInt();

                return DropdownMenuItem<int?>(
                  value: id,
                  child: Text(sousCategorie['name_fr'].toString()),
                );
              }),
            ],
            onChanged: _enregistrement
                ? null
                : (value) async {
                    setState(() {
                      _subcategoryId = value;
                    });

                    await _chargerProduits();
                  },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _produits.any(
              (produit) => (produit['id'] as num).toInt() == _productId,
            )
                ? _productId
                : null,
            decoration: const InputDecoration(
              labelText: 'Produit',
              border: OutlineInputBorder(),
            ),
            items: _produits.map((produit) {
              final id = (produit['id'] as num).toInt();

              return DropdownMenuItem<int>(
                value: id,
                child: Text(
                  '${produit['name_fr']} — ${produit['unit']}',
                ),
              );
            }).toList(),
            onChanged: _enregistrement
                ? null
                : (value) async {
                    setState(() {
                      _productId = value;
                    });

                    if (value != null) {
                      await _chargerOptions();
                    }
                  },
          ),
          if (_productId != null) ...[
            const SizedBox(height: 24),
            Text(
              'Options du produit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_options.isEmpty)
              const Text(
                'Aucune option supplémentaire pour ce produit.',
                style: TextStyle(color: Colors.grey),
              ),
            ..._options.map(_champOption),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _enregistrement ? null : _enregistrer,
              icon: _enregistrement
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Ajouter à mes produits'),
            ),
          ),
        ],
      ),
    );
  }
}
