# Consignes pour Claude

Projet : RTS Godot 4 (GDScript). Référence de conception : `docs/GDD.md`. État : `docs/PROTOTYPE_1.md`.

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

- Toute valeur non définie par le GDD va dans `scripts/core/game_config.gd` (ou le `.tres` concerné),
  marquée `[PROVISOIRE]`, et est listée dans le document du prototype en cours avec la question ouverte.
- Lancer les tests : `godot --headless --path . -s res://tests/run_tests.gd` (code de sortie 0 = OK).
- Le code et les commentaires sont en français.
