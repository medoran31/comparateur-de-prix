import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

class ImporterProduitsPage extends StatefulWidget {
  const ImporterProduitsPage({super.key});

  @override
  State<ImporterProduitsPage> createState() => _ImporterProduitsPageState();
}

class _ImporterProduitsPageState extends State<ImporterProduitsPage> {
  final supabase = Supabase.instance.client;

  bool _enChargement = false;
  bool _enImport = false;
  List<List<dynamic>> _lignes = [];
  String? _nomFichier;

  Map<String, int> _categoriesParNom = {};
  Map<String, Map<String, int>> _sousCategoriesParCategorie = {};

  List<String> _resultats = [];

  Future<void> _choisirFichier() async {
    final resultat = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (resultat == null || resultat.files.isEmpty) return;

    final fichier = resultat.files.first;
    final octets = fichier.bytes;

    if (octets == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible de lire ce fichier.")),
        );
      }
      return;
    }

    setState(() {
      _enChargement = true;
      _resultats = [];
    });

    try {
      final texte = utf8.decode(octets);
      final lignes = const CsvToListConverter(eol: '\n')
          .convert(texte, shouldParseNumbers: false);

      if (lignes.length < 2) {
        throw Exception("Le fichier ne contient aucune ligne de donnees.");
      }

      await _chargerCategories();

      setState(() {
        _lignes = lignes;
        _nomFichier = fichier.name;
        _enChargement = false;
      });
    } catch (e) {
      setState(() {
        _enChargement = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur de lecture : $e")),
        );
      }
    }
  }

  Future<void> _chargerCategories() async {
    final categories = await supabase
        .from('categories')
        .select('id, name_fr')
        .eq('active', true);

    _categoriesParNom = {};
    for (final c in categories) {
      _categoriesParNom[(c['name_fr'] as String).trim().toLowerCase()] =
          (c['id'] as num).toInt();
    }

    final sousCategories = await supabase
        .from('subcategories')
        .select('id, category_id, name_fr')
        .eq('active', true);

    _sousCategoriesParCategorie = {};
    for (final s in sousCategories) {
      final categoryId = (s['category_id'] as num).toInt();
      final nom = (s['name_fr'] as String).trim().toLowerCase();
      _sousCategoriesParCategorie.putIfAbsent(categoryId.toString(), () => {});
      _sousCategoriesParCategorie[categoryId.toString()]![nom] =
          (s['id'] as num).toInt();
    }
  }

  Future<void> _importer() async {
    setState(() {
      _enImport = true;
      _resultats = [];
    });

    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _enImport = false;
      });
      return;
    }

    var reussis = 0;
    var echecs = 0;

    for (var i = 1; i < _lignes.length; i++) {
      final ligne = _lignes[i];
      if (ligne.isEmpty || ligne.every((c) => c.toString().trim().isEmpty)) {
        continue;
      }

      try {
        final nomFr = ligne.isNotEmpty ? ligne[0].toString().trim() : '';
        final nomAr = ligne.length > 1 ? ligne[1].toString().trim() : '';
        final categorieTexte = ligne.length > 2 ? ligne[2].toString().trim() : '';
        final sousCategorieTexte =
        ligne.length > 3 ? ligne[3].toString().trim() : '';
        final marque = ligne.length > 4 ? ligne[4].toString().trim() : '';
        final unite = ligne.length > 5 ? ligne[5].toString().trim() : '';

        if (nomFr.isEmpty || nomAr.isEmpty || unite.isEmpty) {
          throw Exception("ligne incomplete");
        }

        final categoryId = _categoriesParNom[categorieTexte.toLowerCase()];
        if (categoryId == null) {
          throw Exception("categorie introuvable : $categorieTexte");
        }

        int? subcategoryId;
        if (sousCategorieTexte.isNotEmpty) {
          subcategoryId = _sousCategoriesParCategorie[categoryId.toString()]
          ?[sousCategorieTexte.toLowerCase()];
          if (subcategoryId == null) {
            throw Exception("sous-categorie introuvable : $sousCategorieTexte");
          }
        }

        await supabase.from('products').insert({
          'name_fr': nomFr,
          'name_ar': nomAr,
          'category_id': categoryId,
          'subcategory_id': subcategoryId,
          'brand': marque.isEmpty ? null : marque,
          'unit': unite,
          'created_by': user.id,
          'options': <String, dynamic>{},
          'active': true,
        });

        reussis++;
        _resultats.add("Ligne " + (i + 1).toString() + " : " + nomFr + " -> ajoute");
      } catch (e) {
        echecs++;
        _resultats.add("Ligne " + (i + 1).toString() + " : erreur -> " + e.toString());
      }
    }

    setState(() {
      _enImport = false;
      _resultats.insert(
        0,
        reussis.toString() + " produit(s) ajoute(s), " + echecs.toString() + " erreur(s).",
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Importer des produits")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Format attendu (fichier CSV)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Colonnes, dans cet ordre, avec une ligne d'en-tete :\n"
                          "nom_fr, nom_ar, categorie, sous_categorie, marque, unite\n\n"
                          "La categorie et la sous-categorie doivent correspondre "
                          "exactement a celles deja presentes dans l'application. "
                          "La sous-categorie et la marque peuvent etre laissees vides.",
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _enChargement || _enImport ? null : _choisirFichier,
              icon: const Icon(Icons.upload_file),
              label: Text(_nomFichier == null ? "Choisir un fichier CSV" : _nomFichier!),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 8),
            if (_lignes.isNotEmpty)
              Text(
                (_lignes.length - 1).toString() + " ligne(s) de produits detectee(s).",
                style: const TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 16),
            if (_lignes.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _enImport ? null : _importer,
                icon: _enImport
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.cloud_upload),
                label: const Text("Importer ces produits"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: const Color(0xFF1F3A5F),
                ),
              ),
            const SizedBox(height: 16),
            if (_resultats.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _resultats.length,
                  itemBuilder: (context, index) {
                    final estErreur = _resultats[index].contains("erreur");
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _resultats[index],
                        style: TextStyle(
                          fontSize: 12,
                          color: estErreur ? Colors.red : Colors.black87,
                        ),
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