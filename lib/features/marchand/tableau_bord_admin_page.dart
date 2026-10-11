import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'gestion_produits_page.dart';
import 'ajouter_marchand_page.dart';
import 'modifier_marchand_page.dart';
import 'importer_produits_page.dart';
import 'importer_marchands_page.dart';
import 'changer_code_admin_page.dart';

class TableauBordAdminPage extends StatefulWidget {
  const TableauBordAdminPage({super.key});

  @override
  State<TableauBordAdminPage> createState() => _TableauBordAdminPageState();
}

class _TableauBordAdminPageState extends State<TableauBordAdminPage> {
  final supabase = Supabase.instance.client;

  bool _enChargement = true;
  String? _erreur;

  int _nombreMarchands = 0;
  int _nombreProduits = 0;

  List<Map<String, dynamic>> _marchands = [];

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
      final utilisateur = supabase.auth.currentUser;

      if (utilisateur == null) {
        setState(() {
          _erreur = "Vous devez etre connecte.";
          _enChargement = false;
        });
        return;
      }

      final roleResultat = await supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', utilisateur.id)
          .maybeSingle();

      if (roleResultat == null || roleResultat['role'] != 'admin') {
        setState(() {
          _erreur = "Acces refuse : ce compte n est pas administrateur.";
          _enChargement = false;
        });
        return;
      }

      final marchandsResponse = await supabase
          .from('merchants')
          .select('id, name, quarter, phone, status, trial_end')
          .order('name');

      final marchands = List<Map<String, dynamic>>.from(marchandsResponse);

      final produitsResponse = await supabase
          .from('products')
          .select('id')
          .eq('active', true);

      final produits = List<Map<String, dynamic>>.from(produitsResponse);

      if (!mounted) return;

      setState(() {
        _marchands = marchands;
        _nombreMarchands = marchands.length;
        _nombreProduits = produits.length;
        _enChargement = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _erreur = "Erreur de chargement : $e";
        _enChargement = false;
      });
    }
  }

  Future<void> _seDeconnecter() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _toggleSuspension(Map<String, dynamic> marchand) async {
    final statutActuel = marchand['status']?.toString() ?? 'essai';
    final estSuspendu = statutActuel == 'suspendu';
    final nouveauStatut = estSuspendu ? 'actif' : 'suspendu';
    final nom = marchand['name']?.toString() ?? 'ce marchand';

    final confirmer = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(estSuspendu
              ? "Reactiver ce marchand ?"
              : "Suspendre ce marchand ?"),
          content: Text(
            estSuspendu
                ? "$nom redeviendra visible pour les acheteurs et pourra se connecter."
                : "$nom ne sera plus visible pour les acheteurs et ne pourra plus "
                "se connecter, jusqu a ce que vous le reactiviez.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: estSuspendu ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(estSuspendu ? "Reactiver" : "Suspendre"),
            ),
          ],
        );
      },
    );

    if (confirmer != true) return;

    try {
      await supabase
          .from('merchants')
          .update({'status': nouveauStatut})
          .eq('id', marchand['id']);

      await _charger();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(estSuspendu
              ? "$nom a ete reactive."
              : "$nom a ete suspendu."),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : " + e.toString())),
      );
    }
  }

  Widget _carteStatistique(String titre, int valeur, IconData icone) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icone, size: 30, color: const Color(0xFF1F3A5F)),
              const SizedBox(height: 8),
              Text(
                valeur.toString(),
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(titre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Color _couleurStatut(String statut) {
    if (statut == 'actif') return Colors.green;
    if (statut == 'suspendu') return Colors.red;
    return Colors.orange;
  }

  Widget _carte({
    required IconData icone,
    required String titre,
    required String sousTitre,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icone, color: const Color(0xFF1F3A5F)),
        title: Text(titre,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sousTitre),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Administration"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Se deconnecter",
            onPressed: _seDeconnecter,
          ),
        ],
      ),
      body: _enChargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_erreur!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _charger,
                child: const Text("Reessayer"),
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
            const Text(
              "Tableau de bord administrateur",
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text("Gestion de la plateforme",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            Row(
              children: [
                _carteStatistique(
                    "Marchands", _nombreMarchands, Icons.store),
                const SizedBox(width: 12),
                _carteStatistique(
                    "Produits", _nombreProduits, Icons.inventory_2),
              ],
            ),
            const SizedBox(height: 20),
            _carte(
              icone: Icons.inventory_2_outlined,
              titre: "Gestion du catalogue",
              sousTitre:
              "Ajouter, modifier ou supprimer les produits.",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                    const GestionProduitsPage(estAdmin: true),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _carte(
              icone: Icons.upload_file,
              titre: "Importer des produits",
              sousTitre:
              "Ajouter plusieurs produits via un fichier CSV.",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                    const ImporterProduitsPage(),
                  ),
                ).then((_) {
                  if (mounted) _charger();
                });
              },
            ),
            const SizedBox(height: 12),
            _carte(
              icone: Icons.person_add_alt,
              titre: "Ajouter un marchand",
              sousTitre: "Creer un compte et une fiche commerce.",
              onTap: () {
                Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                    const AjouterMarchandPage(),
                  ),
                ).then((cree) {
                  if (cree == true && mounted) _charger();
                });
              },
            ),
            const SizedBox(height: 12),
            _carte(
              icone: Icons.group_add,
              titre: "Importer des marchands",
              sousTitre:
              "Creer plusieurs marchands via un fichier CSV.",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                    const ImporterMarchandsPage(),
                  ),
                ).then((_) {
                  if (mounted) _charger();
                });
              },
            ),
            const SizedBox(height: 12),
            _carte(
              icone: Icons.lock_reset,
              titre: "Changer mon code",
              sousTitre:
              "Modifier le code de connexion administrateur.",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                    const ChangerCodeAdminPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text("Marchands",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              "Touchez un marchand pour le modifier. "
                  "Utilisez l icone a droite pour suspendre.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (_marchands.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("Aucun marchand trouve.",
                      textAlign: TextAlign.center),
                ),
              )
            else
              ..._marchands.map((marchand) {
                final nom =
                    marchand['name']?.toString() ?? "Marchand";
                final quartier =
                    marchand['quarter']?.toString() ?? "";
                final statut =
                    marchand['status']?.toString() ?? "essai";
                final trialEnd =
                marchand['trial_end']?.toString();
                final estSuspendu = statut == 'suspendu';

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                        child: Icon(Icons.store)),
                    title: Text(nom,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      quartier +
                          (trialEnd != null
                              ? " • Essai jusqu au " + trialEnd
                              : ""),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(statut),
                          backgroundColor: _couleurStatut(statut)
                              .withOpacity(0.15),
                          labelStyle: TextStyle(
                              color: _couleurStatut(statut)),
                        ),
                        IconButton(
                          icon: Icon(
                            estSuspendu
                                ? Icons.play_circle_outline
                                : Icons.block,
                            color: estSuspendu
                                ? Colors.green
                                : Colors.red,
                          ),
                          tooltip: estSuspendu
                              ? "Reactiver"
                              : "Suspendre",
                          onPressed: () =>
                              _toggleSuspension(marchand),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ModifierMarchandPage(
                                  marchand: marchand),
                        ),
                      ).then((modifie) {
                        if (modifie == true && mounted) {
                          _charger();
                        }
                      });
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}