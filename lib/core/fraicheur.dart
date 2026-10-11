import 'package:flutter/material.dart';

/// Outils pour afficher la fraicheur d'un prix.
///
/// Un comparateur de prix n'est utile que si les prix sont recents.
/// Ces fonctions permettent d'indiquer clairement au client depuis quand
/// un prix a ete mis a jour, avec un code couleur (vert / orange / rouge).

/// Nombre de jours entiers ecoules depuis une date fournie par Supabase.
/// Retourne 9999 si la date est absente ou illisible.
int joursDepuis(String? dateTexte) {
  final date = DateTime.tryParse(dateTexte ?? '');
  if (date == null) return 9999;
  return DateTime.now().difference(date).inDays;
}

/// Phrase lisible decrivant l'anciennete d'un prix.
String texteDelai(String? dateTexte) {
  final date = DateTime.tryParse(dateTexte ?? '');
  if (date == null) return 'date inconnue';

  final difference = DateTime.now().difference(date);

  if (difference.inMinutes < 60) return "mis a jour a l'instant";
  if (difference.inHours < 24) {
    return 'mis a jour il y a ${difference.inHours} h';
  }
  if (difference.inDays == 1) return 'mis a jour hier';
  if (difference.inDays < 7) {
    return 'mis a jour il y a ${difference.inDays} jours';
  }
  if (difference.inDays < 14) return 'mis a jour la semaine derniere';
  if (difference.inDays < 31) {
    return 'mis a jour il y a ${difference.inDays ~/ 7} semaines';
  }
  if (difference.inDays < 62) return 'mis a jour il y a 1 mois';
  return 'mis a jour il y a ${difference.inDays ~/ 30} mois';
}

/// Un prix est considere "ancien" au-dela de 30 jours.
bool prixAncien(String? dateTexte) => joursDepuis(dateTexte) > 30;

/// Couleur conseillee selon la fraicheur :
/// - vert  : 7 jours ou moins (fiable) ;
/// - orange : entre 8 et 30 jours (a confirmer) ;
/// - rouge : plus de 30 jours (ancien).
Color couleurFraicheur(String? dateTexte) {
  final jours = joursDepuis(dateTexte);
  if (jours <= 7) return const Color(0xFF2E7D32); // vert
  if (jours <= 30) return const Color(0xFFE65100); // orange
  return const Color(0xFFC62828); // rouge
}

/// Petite ligne "mis a jour il y a X" avec un code couleur.
class LigneFraicheurPrix extends StatelessWidget {
  final String? dateTexte;
  final double taillePolice;

  const LigneFraicheurPrix(this.dateTexte, {
    super.key,
    this.taillePolice = 12,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = couleurFraicheur(dateTexte);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: taillePolice + 1, color: couleur),
        const SizedBox(width: 4),
        Text(
          texteDelai(dateTexte),
          style: TextStyle(
            fontSize: taillePolice,
            color: couleur,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
