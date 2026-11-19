# Prototype 5 — Mana et système de cartes

Le Prototype 4 (jungle, monstres, boss, mines) attend les valeurs de l'auteur (voir `docs/QUESTIONS.md`) ;
le moteur de cartes, entièrement décrit par le GDD, a été construit en attendant.

## Ce qui est implémenté

| Système | Fichier | Contenu |
|---|---|---|
| Données de carte | `scripts/data/card_data.gd`, `data/cards/*.tres` | Catégorie, coût en mana, effet + paramètres, usage unique |
| Deck / main / mana | `scripts/cards/player_cards.gd` | Pioche, jeu, retour sous le deck, malus, bannissement, cartes du terrain, régénération |
| Decks des joueurs | `scripts/cards/card_system.gd` | 10 bonus + 5 malus + 5 neutres (identiques pour les deux) ; mana à chaque tour |
| Interface | `scripts/ui/hand_panel.gd`, `hud.gd` | Main de cartes de la maquette, mana (cristal bleu) dans la barre du haut |

## Règles du GDD appliquées

- Deck de 20 : 10 bonus, 5 malus, 5 neutres ; neutres tirés au hasard, **les mêmes pour les deux joueurs** (§9).
- Main initiale 3, limite 3 (§9).
- Jouer une carte : mana payé → effet → la carte retourne **sous** le deck → la main est complétée (§9).
- Cartes à usage unique : disparaissent après activation (§9).
- **Malus** : occupent la main (1 normale + 2 malus = 1 carte exploitable) ; on peut les garder ou les
  activer : effet, retour sous le deck, pioche (§7.2).
- **Cartes du terrain** : ajoutées directement à la main, jamais au deck, disparaissent après usage (§9)
  — prêtes pour les butins de monstres et de boss (Prototype 4).
- **Bannissement** : retire définitivement une carte malus (§7.3, §9).
- **Mana** : régénération automatique, identique pour les deux joueurs, payé à l'activation,
  modifiable par un bonus temporaire (§4).

## Cartes disponibles (exemples tirés du GDD)

| Carte | Catégorie | Effet | Mana |
|---|---|---|---|
| Trésor royal | Bonus | +200 Gd immédiatement (§7.1) | 3 * |
| Afflux de mana | Bonus | Régénération +50 % pendant 30 tours * (§4.2) | 2 * |
| Extension de main | Neutre | Limite de la main +1 (usage unique *) | 1 * |
| Destruction | Neutre | Une carte de la main est défaussée sous le deck * | 1 * |
| Bannissement | Neutre | Un malus de la main est retiré définitivement | 1 * |
| Nouvelle pioche | Neutre | Pioche une carte de plus (au-delà de la limite *) | 1 * |
| Malédiction (exemple) | Malus | Aucun effet : sert à tester l'encombrement | 0 |

\* provisoire. Deck de base provisoire : 5 Trésor royal + 5 Afflux de mana + 5 Malédiction + 5 neutres.

## Commandes

- Clic sur une carte : la jouer (grisée si mana insuffisant). Survol : description.
- Destruction / Bannissement : clic sur la carte, puis clic sur la carte cible. Échap ou ⊘ : annuler (mana rendu).

## Valeurs PROVISOIRES

| Sujet | Valeur | Où |
|---|---|---|
| Régénération du mana | 0,25 par tour | `GameConfig.MANA_REGEN_PER_TURN` |
| Mana maximum | 10 | `GameConfig.MANA_MAX` |
| Coûts et durées des cartes | voir tableau | `data/cards/*.tres` |
| Deck de base | voir ci-dessus | `CardSystem.DEFAULT_BONUS / DEFAULT_MALUS` |
