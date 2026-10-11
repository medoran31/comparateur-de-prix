import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/device_id.dart';
import '../../core/favoris.dart';
import '../../core/fraicheur.dart';
import '../../core/partage.dart';

class FicheMarchandPage extends StatefulWidget {
  final String marchandId;
  final String marchandNom;
  final String quartier;
  final double? lat;
  final double? lng;

  const FicheMarchandPage({
    super.key,
    required this.marchandId,
    required this.marchandNom,
    required this.quartier,
    this.lat,
    this.lng,
  });

  @override
  State<FicheMarchandPage> createState() => _FicheMarchandPageState();
}

class _FicheMarchandPageState extends State<FicheMarchandPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _prix = [];
  bool _enChargement = true;
  final Set<int> _dejaSignales = {};
  bool _estFavori = false;

  @override
  void initState() {
    super.initState();
    _chargerPrix();
    _chargerFavori();
    _enregistrerEvenement("fiche_vue");
  }

  Future<void> _chargerFavori() async {
    final resultat = await estFavori(widget.marchandId);
    setState(() {
      _estFavori = resultat;
    });
  }

  Future<void> _toggleFavori() async {
    if (_estFavori) {
      await retirerFavori(widget.marchandId);
    } else {
      await ajouterFavori(widget.marchandId);
      _enregistrerEvenement("favori");
    }
    setState(() {
      _estFavori = !_estFavori;
    });
  }

  Future<void> _enregistrerEvenement(String type) async {
    try {
      final idAppareil = await obtenirIdAppareil();
      await supabase.from('events').insert({
        'type': type,
        'merchant_id': widget.marchandId,
        'device_id': idAppareil,
      });
    } catch (e) {
      // Une erreur ici ne doit pas gêner l'utilisateur, mais on la trace
      // dans les logs pour pouvoir diagnostiquer les statistiques à zéro.
      debugPrint('[AS3AR] Événement "$type" non enregistré : $e');
    }
  }

  Future<void> _chargerPrix() async {
    try {
      final resultats = await supabase
          .from('prices')
          .select('id, amount_da, created_at, product_id, products(name_fr)')
          .eq('merchant_id', widget.marchandId)
          .order('created_at', ascending: false);

      final Map<int, Map<String, dynamic>> dernierPrixParProduit = {};
      for (final ligne in resultats) {
        final idProduit = ligne['product_id'] as int;
        if (!dernierPrixParProduit.containsKey(idProduit)) {
          dernierPrixParProduit[idProduit] = ligne;
        }
      }

      setState(() {
        _prix = dernierPrixParProduit.values.toList();
        _enChargement = false;
      });
    } catch (e) {
      setState(() {
        _enChargement = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur de chargement")),
        );
      }
    }
  }

  Future<void> _ouvrirItineraire() async {
    if (widget.lat == null || widget.lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Position non disponible pour ce commerce.")),
      );
      return;
    }
    final lat = widget.lat!;
    final lng = widget.lng!;
    _enregistrerEvenement("itineraire");

    final destination = "$lat,$lng";
    final libelle = Uri.encodeComponent(widget.marchandNom);

    // On tente plusieurs adresses, de la plus native a la plus securitaire.
    final tentatives = <String>[
      'geo:$destination?q=$destination($libelle)',
      'google.navigation:q=$destination',
      'https://www.google.com/maps/dir/?api=1'
          '&destination=$destination&travelmode=driving',
    ];

    for (final url in tentatives) {
      try {
        final ouverte = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        ).timeout(const Duration(seconds: 5));
        if (ouverte) return;
      } catch (_) {
        // Echec : on essaie la tentative suivante.
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Navigation impossible sur cet appareil.")),
    );
  }

  Future<void> _signaler(int prixId, String type) async {
    if (_dejaSignales.contains(prixId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vous avez déjà répondu pour ce prix aujourd'hui.")),
      );
      return;
    }
    try {
      final idAppareil = await obtenirIdAppareil();
      await supabase.from('price_reports').insert({
        'price_id': prixId,
        'kind': type,
        'device_id': idAppareil,
      });
      setState(() {
        _dejaSignales.add(prixId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(type == 'confirme'
                ? 'Merci pour votre confirmation.'
                : 'Merci pour votre signalement.'),
          ),
        );
      }
    } catch (e) {
      final texteErreur = e.toString();
      if (texteErreur.contains("23505")) {
        setState(() {
          _dejaSignales.add(prixId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Vous avez déjà répondu pour ce prix aujourd'hui.")),
          );
        }
      } else {
        debugPrint('[AS3AR] Signalement "$type" non enregistré : $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Une erreur est survenue.")),
          );
        }
      }
    }
  }

  Future<void> _partager() async {
    await partagerTexte(
      messagePartageMarchand(widget.marchandNom, widget.quartier),
      sujet: widget.marchandNom,
    );
  }

  void _afficherQr() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("QR code du commerce"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                data: contenuQrMarchand(widget.marchandNom, widget.quartier),
                version: QrVersions.auto,
                size: 220,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Faites scanner ce code pour decouvrir les prix de ce commerce sur AS3AR.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.marchandNom),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Partager',
            onPressed: _partager,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'QR code',
            onPressed: _afficherQr,
          ),
          IconButton(
            icon: Icon(
              _estFavori ? Icons.favorite : Icons.favorite_border,
              color: _estFavori ? Colors.red : null,
            ),
            onPressed: _toggleFavori,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.quartier, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _ouvrirItineraire,
                  icon: const Icon(Icons.directions),
                  label: const Text("Itinéraire"),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _enChargement
                ? const Center(child: CircularProgressIndicator())
                : _prix.isEmpty
                ? const Center(
                child: Text("Aucun prix disponible pour le moment."))
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _prix.length,
              itemBuilder: (context, index) {
                final ligne = _prix[index];
                final prixId = ligne['id'] as int;
                final dejaFait = _dejaSignales.contains(prixId);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ligne['products']['name_fr'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500),
                            ),
                            Text(
                              "${ligne['amount_da']} DA",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ],
                        ),
                        LigneFraicheurPrix(ligne['created_at']),
                        const SizedBox(height: 8),
                        if (dejaFait)
                          const Text("Merci pour votre retour.",
                              style:
                              TextStyle(color: Colors.grey))
                        else
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _signaler(prixId, 'confirme'),
                                  icon: const Icon(Icons.check,
                                      size: 18),
                                  label: const Text("Confirmé"),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _signaler(prixId, 'faux'),
                                  icon: const Icon(Icons.flag,
                                      size: 18),
                                  label: const Text("Faux"),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
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