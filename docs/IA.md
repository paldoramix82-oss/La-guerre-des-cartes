# IA simple (adversaire de test)

`scripts/ai/simple_ai.gd` — active par défaut pour le **Joueur 2** (`GameConfig.AI_ENABLED`, `AI_TEAM`).
Elle joue avec **les mêmes règles** que le joueur, en appelant les mêmes fonctions.

| Domaine | Comportement |
|---|---|
| Ouvriers | Récoltent baies (si nourriture < 60) ou bois ; un sur deux part construire un chantier en attente |
| Construction | Ordre fixe (Culture, Cabane Ouvrier, Culture, Maison, Caserne, Ferme, …, Tour Archer), puis selon les besoins (Maison si peu d'habitants, Culture / Ferme si la nourriture baisse) ; en quinconce près de la base |
| Recrutement | Guerrier, Archer, Guerrier, Cavalier, Archer… tant qu'il reste 30 Nourri ; des Mineurs pour ses mines |
| Nourriture | Toutes ses escouades sont « nourries en priorité » |
| Mines | L'or ne venant que des mines : dès 10 soldats, l'armée nettoie la route et capture la mine la moins gardée ; l'IA garde l'or pour l'exploiter, la garde jusqu'à la construction, puis y envoie des mineurs |
| Armée | Défend la base (intrus à moins de 14 cases) ; une fois une mine exploitée et 12 soldats réunis, attaque les unités puis les bâtiments du joueur ; se replie sous 4 soldats |

Simplification : l'IA connaît la position des bâtiments adverses (elle ne subit pas le brouillard).
Tab (test) : en prenant le contrôle du Joueur 2, on désactive l'IA.

Test en accéléré (sans adversaire actif) : mine capturée vers 4 min, exploitée vers 5 min, armée de ~15
escouades vers 15 min.
