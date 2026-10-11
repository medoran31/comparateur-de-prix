import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AjouterProduitCataloguePage extends StatefulWidget {
  const AjouterProduitCataloguePage({super.key});

  @override
  State<AjouterProduitCataloguePage> createState() =>
      _AjouterProduitCataloguePageState();
}

class _AjouterProduitCataloguePageState
    extends State<AjouterProduitCataloguePage> {
  final supabase = Supabase.instance.client;

  bool _chargement = true;
  bool _enregistrement = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _sousCategories = [];

  int? _categoryId;
  int? _subcategoryId;

  final _nomFrController = TextEditingController();
  final _nomArController = TextEditingController();
  final _marqueController = TextEditingController();
  final _unitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chargerCategories();
  }

  @override
  void dispose() {
    _nomFrController.dispose();
    _nomArController.dispose();
    _marqueController.dispose();
    _unitController.dispose();
    super.dispose();
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
        SnackBar(content: Text('Erreur de chargement : $e')),
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
    });
  }

  Future<void> _enregistrer() async {
    final nomFr = _nomFrController.text.trim();
    final nomAr = _nomArController.text.trim();
    final marque = _marqueController.text.trim();
    final unite = _unitController.text.trim();

    if (nomFr.isEmpty ||
        nomAr.isEmpty ||
        unite.isEmpty ||
        _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Remplissez le nom français, le nom arabe, la catégorie et l’unité.',
          ),
        ),
      );
      return;
    }

    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez être connecté.'),
        ),
      );
      return;
    }

    setState(() {
      _enregistrement = true;
    });

    try {
      await supabase.from('products').insert({
        'name_fr': nomFr,
        'name_ar': nomAr,
        'category_id': _categoryId,
        'subcategory_id': _subcategoryId,
        'brand': marque.isEmpty ? null : marque,
        'unit': unite,
        'created_by': user.id,
        'options': <String, dynamic>{},
        'active': true,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produit ajouté au catalogue.'),
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
          content: Text('Impossible d’ajouter le produit : $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ajouter au catalogue'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter au catalogue'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nomFrController,
            enabled: !_enregistrement,
            decoration: const InputDecoration(
              labelText: 'Nom français',
              hintText: 'Ex. Huile de table',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nomArController,
            enabled: !_enregistrement,
            textDirection: TextDirection.rtl,
            decoration: const InputDecoration(
              labelText: 'Nom arabe',
              hintText: 'مثال: زيت المائدة',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
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
                child: Text('Aucune sous-catégorie'),
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
                : (value) {
              setState(() {
                _subcategoryId = value;
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _marqueController,
            enabled: !_enregistrement,
            decoration: const InputDecoration(
              labelText: 'Marque (optionnel)',
              hintText: 'Ex. Elio, Cevital, La Belle...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _unitController,
            enabled: !_enregistrement,
            decoration: const InputDecoration(
              labelText: 'Unité',
              hintText: '1 kg, 1 L, 500 g, unité...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _enregistrement ? null : _enregistrer,
              icon: _enregistrement
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.add),
              label: const Text('Ajouter le produit'),
            ),
          ),
        ],
      ),
    );
  }
}