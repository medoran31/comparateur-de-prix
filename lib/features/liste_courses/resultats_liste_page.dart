import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../recherche/fiche_marchand_page.dart';
import '../../core/partage.dart';

class ResultatsListePage extends StatefulWidget {
  final List<Map<String, dynamic>> produits;

  const ResultatsListePage({super.key, required this.produits});

  @override
  State<ResultatsListePage> createState() => _ResultatsListePageState();
}

class _ResultatsListePageState extends State<ResultatsListePage> {
  final supabase = Supabase.instance.client;
  bool _enChargement = true;
  String? _erreur;
  List<Map<String, dynamic>> _resultatsParMarchand = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _enChargement = true;
      _erreur = null;
    });
    try {
      final idsProduits = widget.produits.map((p) => p['id'] as int).toList();

      final prix = await supabase
          .from('prices')
          .select(
          'id, amount_da, created_at, product_id, merchant_id, merchants(id, name, quarter, lat, lng)')
          .inFilter('product_id', idsProduits)
          .order('created_at', ascending: false);

      // On ne garde que le prix le plus recent par (marchand, produit).
      final Map<String, Map<String, dynamic>> dernierPrix = {};
      for (final ligne in prix) {
        final cle = '${ligne['merchant_id']}_${ligne['product_id']}';
        if (!dernierPrix.containsKey(cle)) {
          dernierPrix[cle] = ligne;
        }
      }

      // On regroupe par marchand.
      final Map<String, Map<String, dynamic>> parMarchand = {};
      for (final ligne in dernierPrix.values) {
        final idMarchand = ligne['merchant_id'] as String;
        final marchand = ligne['merchants'];
        if (!parMarchand.containsKey(idMarchand)) {
          parMarchand[idMarchand] = {
            'marchand': marchand,
            'total': 0.0,
            'detail': <int, num>{},
          };
        }
        final idProduit = ligne['product_id'] as int;
        final montant = ligne['amount_da'] as num;
        (parMarchand[idMarchand]!['detail'] as Map<int, num>)[idProduit] =
            montant;
        parMarchand[idMarchand]!['total'] =
            (parMarchand[idMarchand]!['total'] as double) + montant.toDouble();
      }

      final liste = parMarchand.values.toList();

      // Tri : d'abord les marchands qui couvrent le plus de produits,
      // puis par total croissant.
      liste.sort((a, b) {
        final couvertureA = (a['detail'] as Map).length;
        final couvertureB = (b['detail'] as Map).length;
        if (couvertureA != couvertureB) {
          return couvertureB.compareTo(couvertureA);
        }
        return (a['total'] as double).compareTo(b['total'] as double);
      });

      setState(() {
        _resultatsParMarchand = liste;
        _enChargement = false;
      });
    } catch (e) {
      setState(() {
        _erreur = 'Erreur de chargement : $e';
        _enChargement = false;
      });
    }
  }

  Future<void> _partager() async {
    final lignes = _resultatsParMarchand.map((e) {
      final marchand = e['marchand'];
      final detail = e['detail'] as Map<int, num>;
      final total = e['total'] as double;
      return "- ${marchand['name']} (${marchand['quarter']}) : "
          "${total.toStringAsFixed(0)} DA "
          "(${detail.length}/${widget.produits.length} produits)";
    }).join('\n');
    await partagerTexte(
      messagePartagePanier("Comparaison de mon panier :\n$lignes"),
      sujet: 'Comparaison de panier',
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalProduits = widget.produits.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparaison du panier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Partager',
            onPressed: _resultatsParMarchand.isEmpty ? null : _partager,
          ),
        ],
      ),
      body: _enChargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(child: Text(_erreur!))
          : _resultatsParMarchand.isEmpty
          ? const Center(
          child: Text(
              'Aucun marchand ne vend ces produits pour le moment.'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _resultatsParMarchand.length,
        itemBuilder: (context, index) {
          final entree = _resultatsParMarchand[index];
          final marchand = entree['marchand'];
          final detail = entree['detail'] as Map<int, num>;
          final total = entree['total'] as double;
          final couverture = detail.length;
          final complet = couverture == totalProduits;

          final produitsManquants = widget.produits
              .where((p) => !detail.containsKey(p['id']))
              .map((p) => p['name_fr'])
              .join(', ');

          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              title: Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(marchand['name'],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                  ),
                  Text('${total.toStringAsFixed(0)} DA',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(marchand['quarter']),
                  const SizedBox(height: 4),
                  Text(
                    complet
                        ? 'Tous les produits disponibles ($couverture/$totalProduits)'
                        : '$couverture/$totalProduits produits disponibles',
                    style: TextStyle(
                      color:
                      complet ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!complet)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Manquant : $produitsManquants',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FicheMarchandPage(
                      marchandId: marchand['id'],
                      marchandNom: marchand['name'],
                      quartier: marchand['quarter'],
                      lat: marchand['lat'] != null
                          ? (marchand['lat'] as num).toDouble()
                          : null,
                      lng: marchand['lng'] != null
                          ? (marchand['lng'] as num).toDouble()
                          : null,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}