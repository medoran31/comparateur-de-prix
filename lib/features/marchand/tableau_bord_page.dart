import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import 'mes_prix_page.dart';
import 'gestion_produits_page.dart';

const String numeroWhatsAppOrganisateur = "213771331792";

class TableauBordPage extends StatefulWidget {
  const TableauBordPage({super.key});

  @override
  State<TableauBordPage> createState() => _TableauBordPageState();
}

class _TableauBordPageState extends State<TableauBordPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _controleurLien = TextEditingController();

  bool _enChargement = true;
  String? _erreur;

  bool _enEnregistrementPosition = false;
  bool _enEnregistrementLien = false;

  String _marchandId = "";
  String _nomCommerce = "";
  String? _dateFinEssai;

  double? _lat;
  double? _lng;

  int _consultations = 0;
  int _itineraires = 0;
  int _favoris = 0;

  bool _confirmeAujourdHui = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _controleurLien.dispose();
    super.dispose();
  }

  // =========================================================
  // CHARGEMENT DU TABLEAU DE BORD
  // =========================================================

  Future<void> _charger() async {
    setState(() {
      _enChargement = true;
      _erreur = null;
    });

    try {
      final utilisateur = supabase.auth.currentUser;

      if (utilisateur == null) {
        setState(() {
          _erreur = "Vous devez être connecté.";
          _enChargement = false;
        });
        return;
      }

      final userId = utilisateur.id;

      final marchands = await supabase
          .from('merchants')
          .select('id, name, trial_end, lat, lng')
          .eq('user_id', userId);

      if (marchands.isEmpty) {
        setState(() {
          _erreur = "Aucune fiche marchand trouvée pour ce compte.";
          _enChargement = false;
        });
        return;
      }

      final marchand = marchands[0];

      _marchandId = marchand['id'];
      _nomCommerce = marchand['name'];
      _dateFinEssai = marchand['trial_end'];

      _lat = marchand['lat'] != null
          ? (marchand['lat'] as num).toDouble()
          : null;

      _lng = marchand['lng'] != null
          ? (marchand['lng'] as num).toDouble()
          : null;

      // -------------------------------------------------------
      // Statistiques des 7 derniers jours
      // -------------------------------------------------------

      final ilYA7Jours = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String();

      final evenements = await supabase
          .from('events')
          .select('type')
          .eq('merchant_id', _marchandId)
          .gte('created_at', ilYA7Jours);

      var compteConsultations = 0;
      var compteItineraires = 0;
      var compteFavoris = 0;

      for (final ligne in evenements) {
        final type = ligne['type'];

        if (type == 'fiche_vue') {
          compteConsultations++;
        }

        if (type == 'itineraire') {
          compteItineraires++;
        }

        if (type == 'favori') {
          compteFavoris++;
        }
      }

      // -------------------------------------------------------
      // Vérifier si les prix ont été mis à jour aujourd'hui
      // -------------------------------------------------------

      final debutAujourdHui = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ).toIso8601String();

      final prixAujourdHui = await supabase
          .from('prices')
          .select('id')
          .eq('merchant_id', _marchandId)
          .gte('created_at', debutAujourdHui)
          .limit(1);

      setState(() {
        _consultations = compteConsultations;
        _itineraires = compteItineraires;
        _favoris = compteFavoris;
        _confirmeAujourdHui = prixAujourdHui.isNotEmpty;
        _enChargement = false;
      });
    } catch (e) {
      setState(() {
        _erreur = "Erreur de chargement : $e";
        _enChargement = false;
      });
    }
  }

  // =========================================================
  // JOURS RESTANTS DE L'ESSAI
  // =========================================================

  int _joursRestants() {
    if (_dateFinEssai == null) {
      return 0;
    }

    final fin = DateTime.parse(_dateFinEssai!);

    final difference = fin.difference(DateTime.now()).inDays;

    return difference < 0 ? 0 : difference;
  }

  // =========================================================
  // SAUVEGARDER LA POSITION
  // =========================================================

  Future<void> _sauvegarderPosition(
      double lat,
      double lng,
      ) async {
    await supabase
        .from('merchants')
        .update({
      'lat': lat,
      'lng': lng,
    })
        .eq('id', _marchandId);

    setState(() {
      _lat = lat;
      _lng = lng;
    });
  }

  // =========================================================
  // UTILISER LA POSITION ACTUELLE
  // =========================================================

  Future<void> _enregistrerPosition() async {
    setState(() {
      _enEnregistrementPosition = true;
    });

    try {
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Autorisation refusée. Activez la localisation dans les réglages.",
              ),
            ),
          );
        }

        setState(() {
          _enEnregistrementPosition = false;
        });

        return;
      }

      final serviceActive =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceActive) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Veuillez activer la localisation du téléphone.",
              ),
            ),
          );
        }

        setState(() {
          _enEnregistrementPosition = false;
        });

        return;
      }

      final position = await Geolocator.getCurrentPosition();

      await _sauvegarderPosition(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Position enregistrée."),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Impossible d'enregistrer la position.",
            ),
          ),
        );
      }
    }

    setState(() {
      _enEnregistrementPosition = false;
    });
  }

  // =========================================================
  // EXTRAIRE LES COORDONNÉES D'UN LIEN GOOGLE MAPS
  // =========================================================

  Map<String, double>? _extraireCoordonnees(String texte) {
    final motifs = [
      RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)'),
      RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)'),
      RegExp(r'[?&]ll=(-?\d+\.\d+),(-?\d+\.\d+)'),
      RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)'),
    ];

    for (final motif in motifs) {
      final correspondance = motif.firstMatch(texte);

      if (correspondance != null) {
        final lat = double.tryParse(
          correspondance.group(1)!,
        );

        final lng = double.tryParse(
          correspondance.group(2)!,
        );

        if (lat != null && lng != null) {
          return {
            'lat': lat,
            'lng': lng,
          };
        }
      }
    }

    return null;
  }

  // =========================================================
  // RÉSOUDRE UN LIEN GOOGLE MAPS RACCOURCI
  // =========================================================

  Future<String> _resolverUrlFinale(String urlDepart) async {
    var urlActuelle = urlDepart;

    final client = HttpClient();

    try {
      for (var i = 0; i < 6; i++) {
        final requete = await client
            .getUrl(Uri.parse(urlActuelle))
            .timeout(const Duration(seconds: 8));

        requete.followRedirects = false;

        final reponse = await requete
            .close()
            .timeout(const Duration(seconds: 8));

        if (reponse.statusCode >= 300 &&
            reponse.statusCode < 400) {
          final emplacement =
          reponse.headers.value('location');

          if (emplacement == null) {
            break;
          }

          urlActuelle = emplacement.startsWith('http')
              ? emplacement
              : Uri.parse(urlActuelle)
              .resolve(emplacement)
              .toString();
        } else {
          break;
        }
      }
    } catch (e) {
      // On garde la dernière URL connue.
    } finally {
      client.close();
    }

    return urlActuelle;
  }

  // =========================================================
  // ENREGISTRER LA POSITION DEPUIS UN LIEN GOOGLE MAPS
  // =========================================================

  Future<void> _enregistrerDepuisLien() async {
    final lien = _controleurLien.text.trim();

    if (lien.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Collez d'abord un lien Google Maps.",
          ),
        ),
      );

      return;
    }

    setState(() {
      _enEnregistrementLien = true;
    });

    try {
      var coordonnees = _extraireCoordonnees(lien);

      if (coordonnees == null) {
        final urlFinale = await _resolverUrlFinale(lien);

        coordonnees = _extraireCoordonnees(urlFinale);
      }

      if (coordonnees == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Position introuvable. Essayez 'Utiliser ma position actuelle'.",
              ),
            ),
          );
        }

        setState(() {
          _enEnregistrementLien = false;
        });

        return;
      }

      await _sauvegarderPosition(
        coordonnees['lat']!,
        coordonnees['lng']!,
      );

      if (mounted) {
        _controleurLien.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Position enregistrée depuis le lien.",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Erreur lors de la lecture du lien.",
            ),
          ),
        );
      }
    }

    setState(() {
      _enEnregistrementLien = false;
    });
  }

  // =========================================================
  // WHATSAPP
  // =========================================================

  Future<void> _ouvrirWhatsApp() async {
    final texte =
        "Bonjour, je suis $_nomCommerce et je suis intéressé par l'abonnement Standard.";

    final url = Uri.parse(
      "https://wa.me/$numeroWhatsAppOrganisateur"
          "?text=${Uri.encodeComponent(texte)}",
    );

    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  }

  // =========================================================
  // DÉCONNEXION
  // =========================================================

  Future<void> _seDeconnecter() async {
    await supabase.auth.signOut();

    if (mounted) {
      Navigator.of(context).popUntil(
            (route) => route.isFirst,
      );
    }
  }

  // =========================================================
  // CARTE STATISTIQUE
  // =========================================================

  Widget _carteChiffre(
      String titre,
      int valeur,
      IconData icone,
      ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 16,
          ),
          child: Column(
            children: [
              Icon(
                icone,
                color: const Color(0xFF1F3A5F),
              ),

              const SizedBox(height: 8),

              Text(
                valeur.toString(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                titre,
                style: const TextStyle(
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // INTERFACE
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final positionEnregistree =
        _lat != null && _lng != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tableau de bord"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: _seDeconnecter,
          ),
        ],
      ),

      body: _enChargement
          ? const Center(
        child: CircularProgressIndicator(),
      )

          : _erreur != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Text(
                _erreur!,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _charger,
                child: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      )

          : RefreshIndicator(
        onRefresh: _charger,

        child: ListView(
          padding: const EdgeInsets.all(16),

          children: [

            // =====================================================
            // NOM DU COMMERCE
            // =====================================================

            Text(
              _nomCommerce,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              "Cette semaine",
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 16),

            // =====================================================
            // STATISTIQUES
            // =====================================================

            Row(
              children: [
                _carteChiffre(
                  "Consultations",
                  _consultations,
                  Icons.visibility,
                ),

                const SizedBox(width: 8),

                _carteChiffre(
                  "Itinéraires",
                  _itineraires,
                  Icons.directions,
                ),

                const SizedBox(width: 8),

                _carteChiffre(
                  "Favoris",
                  _favoris,
                  Icons.favorite,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // =====================================================
            // RAPPEL DES PRIX
            // =====================================================

            if (!_confirmeAujourdHui)
              Container(
                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius:
                  BorderRadius.circular(8),
                ),

                child: const Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Color(0xFF856404),
                    ),

                    SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        "Vos prix n'ont pas été confirmés aujourd'hui.",
                        style: TextStyle(
                          color: Color(0xFF856404),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // =====================================================
            // POSITION DU COMMERCE
            // =====================================================

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        Icon(
                          positionEnregistree
                              ? Icons.location_on
                              : Icons.location_off,

                          color:
                          positionEnregistree
                              ? Colors.green
                              : Colors.grey,
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: Text(
                            positionEnregistree
                                ? "Position du commerce enregistrée"
                                : "Position du commerce non enregistrée",
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed:
                      _enEnregistrementPosition
                          ? null
                          : _enregistrerPosition,

                      icon:
                      _enEnregistrementPosition
                          ? const SizedBox(
                        height: 16,
                        width: 16,
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(
                        Icons.my_location,
                      ),

                      label: Text(
                        positionEnregistree
                            ? "Mettre à jour avec ma position actuelle"
                            : "Utiliser ma position actuelle",
                      ),

                      style:
                      OutlinedButton.styleFrom(
                        minimumSize:
                        const Size.fromHeight(
                          44,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Divider(),

                    const SizedBox(height: 8),

                    const Text(
                      "Ou collez un lien Google Maps",
                      style: TextStyle(
                        fontWeight:
                        FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      "Dans Google Maps : cherchez votre commerce, touchez Partager, puis Copier le lien.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller:
                      _controleurLien,

                      decoration:
                      const InputDecoration(
                        hintText:
                        "https://maps.app.goo.gl/...",
                        border:
                        OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 8),

                    OutlinedButton.icon(
                      onPressed:
                      _enEnregistrementLien
                          ? null
                          : _enregistrerDepuisLien,

                      icon:
                      _enEnregistrementLien
                          ? const SizedBox(
                        height: 16,
                        width: 16,
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(
                        Icons.link,
                      ),

                      label: const Text(
                        "Enregistrer depuis le lien",
                      ),

                      style:
                      OutlinedButton.styleFrom(
                        minimumSize:
                        const Size.fromHeight(
                          44,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // =====================================================
            // OFFRE D'ESSAI
            // =====================================================

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.timer_outlined,
                ),

                title: const Text(
                  "Offre d'essai",
                ),

                subtitle: Text(
                  "Il reste ${_joursRestants()} jours",
                ),
              ),
            ),

            const SizedBox(height: 24),

            // =====================================================
            // CONFIRMER LES PRIX
            // =====================================================

            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                    const MesPrixPage(),
                  ),
                );
              },

              icon: const Icon(
                Icons.check,
              ),

              label: const Text(
                "Confirmer mes prix",
              ),

              style:
              ElevatedButton.styleFrom(
                padding:
                const EdgeInsets.all(16),
                minimumSize:
                const Size.fromHeight(50),
              ),
            ),

            const SizedBox(height: 12),

            // =====================================================
            // NOUVEAU : MES PRODUITS
            // =====================================================

            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                    const GestionProduitsPage(
                      estAdmin: false,
                    ),
                  ),
                );
              },

              icon: const Icon(
                Icons.inventory_2_outlined,
              ),

              label: const Text(
                "Mes produits",
              ),

              style:
              OutlinedButton.styleFrom(
                padding:
                const EdgeInsets.all(16),
                minimumSize:
                const Size.fromHeight(50),
              ),
            ),

            const SizedBox(height: 12),

            // =====================================================
            // ABONNEMENT STANDARD
            // =====================================================

            OutlinedButton.icon(
              onPressed: _ouvrirWhatsApp,

              icon: const Icon(
                Icons.chat,
              ),

              label: const Text(
                "Passer à Standard, 800 DA/mois",
              ),

              style:
              OutlinedButton.styleFrom(
                padding:
                const EdgeInsets.all(16),
                minimumSize:
                const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}