import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

import '../../main.dart';

class ImporterMarchandsPage extends StatefulWidget {
  const ImporterMarchandsPage({super.key});

  @override
  State<ImporterMarchandsPage> createState() => _ImporterMarchandsPageState();
}

class _ImporterMarchandsPageState extends State<ImporterMarchandsPage> {
  final supabase = Supabase.instance.client;

  bool _enLecture = false;
  bool _enImport = false;
  List<List<dynamic>> _lignes = [];
  String? _nomFichier;
  int _progression = 0;
  int _total = 0;
  String _resume = '';

  final List<Map<String, dynamic>> _resultats = [];

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
      _enLecture = true;
      _resultats.clear();
      _resume = '';
    });

    try {
      String texte;
      try {
        texte = utf8.decode(octets);
      } on FormatException {
        throw Exception(
          "Le fichier n'est pas en UTF-8. Dans Excel : Enregistrer sous > CSV UTF-8.",
        );
      }

      if (texte.startsWith('\uFEFF')) {
        texte = texte.substring(1);
      }

      final premiereLigne = texte.split('\n').first;
      final delimiteur =
      (premiereLigne.contains(';') && !premiereLigne.contains(',')) ? ';' : ',';

      final lignes = CsvToListConverter(fieldDelimiter: delimiteur, eol: '\n')
          .convert(texte, shouldParseNumbers: false);

      if (lignes.length < 2) {
        throw Exception("Le fichier ne contient aucune ligne de donnees.");
      }

      final total = lignes.skip(1).where((ligne) {
        return !(ligne.isEmpty || ligne.every((c) => c.toString().trim().isEmpty));
      }).length;

      setState(() {
        _lignes = lignes;
        _nomFichier = fichier.name;
        _total = total;
        _progression = 0;
        _enLecture = false;
      });
    } catch (e) {
      setState(() {
        _enLecture = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _ajouterResultat(bool ok, String texte) {
    if (!mounted) return;
    setState(() {
      _resultats.add({'ok': ok, 'texte': texte});
      _progression++;
    });
  }

  Future<void> _importer() async {
    setState(() {
      _enImport = true;
      _resultats.clear();
      _resume = '';
      _progression = 0;
    });

    var reussis = 0;
    var echecs = 0;
    var interrompu = false;
    final motifIdentifiant = RegExp(r'^[A-Z0-9_]+$');

    for (var i = 1; i < _lignes.length; i++) {
      final ligne = _lignes[i];
      if (ligne.isEmpty || ligne.every((c) => c.toString().trim().isEmpty)) {
        continue;
      }

      final numero = i + 1;
      final identifiant =
      ligne.isNotEmpty ? ligne[0].toString().trim().toUpperCase() : '';
      final code = ligne.length > 1 ? ligne[1].toString().trim() : '';
      final nom = ligne.length > 2 ? ligne[2].toString().trim() : '';
      final quartier = ligne.length > 3 ? ligne[3].toString().trim() : '';

      String? probleme;
      if (identifiant.isEmpty || code.isEmpty || nom.isEmpty || quartier.isEmpty) {
        probleme = "ligne incomplete";
      } else if (!motifIdentifiant.hasMatch(identifiant)) {
        probleme = "identifiant invalide (lettres, chiffres et _ uniquement)";
      } else if (code.length < 6) {
        probleme = "code trop court (6 caracteres minimum)";
      }

      if (probleme != null) {
        echecs++;
        _ajouterResultat(
          false,
          "Ligne " + numero.toString() + " : " + identifiant + " : " + probleme,
        );
        continue;
      }

      // Client temporaire, independant de la session de l'administrateur.
      final clientTemporaire = SupabaseClient(
        supabaseUrl,
        supabaseAnonKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );

      String? nouvelUserId;

      try {
        final inscription = await clientTemporaire.auth.signUp(
          email: identifiant + "@marchands.local",
          password: code,
        );

        nouvelUserId = inscription.user?.id;

        if (nouvelUserId == null) {
          throw Exception("creation du compte echouee");
        }

        await supabase.from('user_roles').insert({
          'user_id': nouvelUserId,
          'role': 'marchand',
        });

        final finEssai = DateTime.now()
            .add(const Duration(days: 28))
            .toIso8601String()
            .split('T')[0];

        await supabase.from('merchants').insert({
          'user_id': nouvelUserId,
          'name': nom,
          'quarter': quartier,
          'phone': identifiant,
          'status': 'essai',
          'trial_end': finEssai,
        });

        reussis++;
        _ajouterResultat(
          true,
          "Ligne " + numero.toString() + " : " + identifiant + " -> cree",
        );
      } catch (e) {
        final message = e.toString().toLowerCase();
        String texteErreur;

        if (message.contains('already registered') ||
            message.contains('already been registered')) {
          texteErreur = "identifiant deja existant";
        } else if (message.contains('rate limit')) {
          texteErreur = "limite de creations atteinte";
          interrompu = true;
        } else if (nouvelUserId != null) {
          texteErreur = "compte cree mais fiche non creee (" + e.toString() + ")";
        } else {
          texteErreur = e.toString().replaceFirst('Exception: ', '');
        }

        echecs++;
        _ajouterResultat(
          false,
          "Ligne " + numero.toString() + " : " + identifiant + " : " + texteErreur,
        );
      } finally {
        await clientTemporaire.dispose();
      }

      if (interrompu) break;

      // Courte pause entre deux creations de comptes.
      await Future.delayed(const Duration(milliseconds: 600));
    }

    if (!mounted) return;

    setState(() {
      _enImport = false;
      _resume = reussis.toString() +
          " marchand(s) cree(s), " +
          echecs.toString() +
          " erreur(s)." +
          (interrompu
              ? " Import interrompu : attendez quelques minutes, puis reimportez uniquement les lignes restantes."
              : "");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Importer des marchands")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Format attendu (fichier CSV)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Colonnes, dans cet ordre, avec une ligne d'en-tete :\n"
                        "identifiant, code, nom, quartier\n\n"
                        "- identifiant : lettres, chiffres et _ , sans espace\n"
                        "- code : 6 caracteres minimum\n"
                        "- chaque marchand recoit 28 jours d'essai\n\n"
                        "Attention : le fichier contient les codes en clair. "
                        "Supprimez-le une fois l'import termine.",
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _enLecture || _enImport ? null : _choisirFichier,
            icon: const Icon(Icons.upload_file),
            label: Text(_nomFichier == null ? "Choisir un fichier CSV" : _nomFichier!),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 8),
          if (_lignes.isNotEmpty)
            Text(
              _total.toString() + " marchand(s) detecte(s) dans le fichier.",
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
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.group_add),
              label: const Text("Creer ces marchands"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: const Color(0xFF1F3A5F),
                foregroundColor: Colors.white,
              ),
            ),
          if (_enImport) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _total == 0 ? null : _progression / _total,
            ),
            const SizedBox(height: 4),
            Text(
              _progression.toString() + " / " + _total.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          if (_resume.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _resume,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 8),
          ..._resultats.map((resultat) {
            final ok = resultat['ok'] == true;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    ok ? Icons.check_circle : Icons.error,
                    size: 16,
                    color: ok ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      resultat['texte'].toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: ok ? Colors.black87 : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}