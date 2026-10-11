import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'tableau_bord_page.dart';
import 'tableau_bord_admin_page.dart';

class ConnexionMarchandPage extends StatefulWidget {
  const ConnexionMarchandPage({super.key});

  @override
  State<ConnexionMarchandPage> createState() => _ConnexionMarchandPageState();
}

class _ConnexionMarchandPageState extends State<ConnexionMarchandPage> {
  final supabase = Supabase.instance.client;

  final _controleurIdentifiant = TextEditingController();
  final _controleurCode = TextEditingController();

  bool _enChargement = false;
  String? _erreur;

  Future<void> _seConnecter() async {
    final identifiant = _controleurIdentifiant.text.trim();
    final code = _controleurCode.text.trim();

    if (identifiant.isEmpty || code.isEmpty) {
      setState(() {
        _erreur = "Merci de remplir les deux champs.";
      });
      return;
    }

    setState(() {
      _enChargement = true;
      _erreur = null;
    });

    try {
      final String emailTechnique;

      if (identifiant.toUpperCase() == 'ADMIN') {
        emailTechnique = 'admin@as7ar.local';
      } else {
        emailTechnique =
        '${identifiant.toUpperCase()}@marchands.local';
      }

      final resultat = await supabase.auth.signInWithPassword(
        email: emailTechnique,
        password: code,
      );

      final utilisateur = resultat.user;

      if (utilisateur == null) {
        throw Exception(
          "Utilisateur introuvable après connexion.",
        );
      }

      final roleResultat = await supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', utilisateur.id)
          .maybeSingle();

      final role = roleResultat?['role']?.toString();

      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const TableauBordAdminPage(),
          ),
        );
        return;
      }

      if (role == 'marchand') {
        final marchandResultat = await supabase
            .from('merchants')
            .select('status')
            .eq('user_id', utilisateur.id)
            .maybeSingle();

        final statut =
        marchandResultat?['status']?.toString();

        if (statut == 'suspendu') {
          await supabase.auth.signOut();

          if (!mounted) return;

          setState(() {
            _erreur =
            "Ce compte a ete suspendu. Contactez l'organisateur.";
            _enChargement = false;
          });

          return;
        }

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const TableauBordPage(),
          ),
        );
        return;
      }

      await supabase.auth.signOut();

      if (!mounted) return;

      setState(() {
        _erreur =
        "Le rôle de ce compte n'est pas défini.";
        _enChargement = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _erreur = "Erreur de connexion : $e";
        _enChargement = false;
      });
    }
  }

  @override
  void dispose() {
    _controleurIdentifiant.dispose();
    _controleurCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Espace marchand"),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.storefront,
                      size: 64,
                      color: Color(0xFF1F3A5F),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      "Connectez-vous avec l'identifiant "
                          "et le code donnés par l'organisateur.",
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    TextField(
                      controller: _controleurIdentifiant,
                      textCapitalization:
                      TextCapitalization.characters,
                      enabled: !_enChargement,
                      decoration: const InputDecoration(
                        labelText: "Identifiant",
                        hintText:
                        "ADMIN ou identifiant marchand",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: _controleurCode,
                      obscureText: true,
                      enabled: !_enChargement,
                      decoration: const InputDecoration(
                        labelText: "Code",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (_erreur != null)
                      Padding(
                        padding:
                        const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _erreur!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                          ),
                        ),
                      ),

                    ElevatedButton(
                      onPressed:
                      _enChargement ? null : _seConnecter,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: _enChargement
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text("Se connecter"),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}