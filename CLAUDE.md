# Consignes pour Claude

Projet : RTS Godot 4 (GDScript). Référence de conception : `docs/GDD.md`. État : `docs/PROTOTYPE_1.md`, `docs/PROTOTYPE_2.md`, `docs/PROTOTYPE_3.md`, `docs/PROTOTYPE_4.md`, `docs/PROTOTYPE_5.md`, `docs/PROTOTYPE_7.md`. Questions en attente : `docs/QUESTIONS.md`. Valeurs : `docs/VALEURS.md`. Carte : `docs/CARTE.md`.

## Règles (GDD §15)

1. Ne pas inventer de mécaniques de gameplay sans validation.
2. Ne pas modifier les valeurs définies dans le GDD sans autorisation.
3. Ne pas supprimer une fonctionnalité existante sans justification.
4. Architecture modulaire, pas de scripts monolithiques.
5. Documenter les systèmes importants.
6. Séparer les données (`data/`, Resources `.tres`) des mécaniques (`scripts/`).
7. Prévoir l'ajout de bâtiments, unités, cartes et héros par données.
8. Tester chaque système avant de passer au suivant.
9. Suivre l'ordre des prototypes (GDD §14) ; RTS fonctionnel d'abord.

## Pratique

- L'auteur préfère donner lui-même les valeurs manquantes : les lui demander. Si une valeur reste
  indispensable pour avancer, la mettre `scripts/core/game_config.gd` (ou le `.tres` concerné),
  marquée `[PROVISOIRE]`, et la lister dans le document du prototype en cours avec la question ouverte.
- Lancer les tests : `tests/run.sh <godot>` (code de sortie 0 = OK ; échoue aussi sur toute `SCRIPT ERROR`).
- Ne jamais passer à une fonction typée un objet qui peut avoir été libéré (unité morte) :
  vérifier `is_instance_valid()` d'abord, sinon Godot lève « previously freed ».
- Commandes : tout doit rester jouable au trackpad Mac (un seul bouton, pas de molette).
- Les tests utilisent la petite carte fixe (`GameMap.generate_placeholder_layout`, `auto_generate = false`) ;
  la grande carte est testée à part (`_test_map_generator`).
- 1 tour = `GameConfig.SECONDS_PER_TURN` (20 s) ; combat et déplacements en secondes.
- Les monstres sont l'équipe `GameConfig.MONSTER_TEAM` (2) : toujours penser à elle (économie, brouillard).
- Le jeu passera à terme en vue isométrique : garder le rendu séparé de la logique de grille.
- Le code et les commentaires sont en français.
