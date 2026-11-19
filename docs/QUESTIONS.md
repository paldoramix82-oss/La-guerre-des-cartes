# Questions pour l'auteur

Répondez dans l'ordre que vous voulez, même partiellement, même en vrac (« pour l'instant » suffit).
Les valeurs déjà données sont dans `docs/VALEURS.md`.

---

## 0. La plus importante

**0.1 — Durée d'un tour.** Toutes vos valeurs sont en « tours » (production, construction, recrutement,
consommation). Aujourd'hui **1 tour = 1 seconde**, donc une Ferme rapporte 25 Nourri par seconde. Pour des
parties de ~30 minutes, combien de secondes doit durer un tour ? (ex. 5 s, 10 s…)

---

## 1. Petites questions en suspens

1. Coût de création d'une unité : **par escouade** (actuel : 50 Gd + 4 Nourri = 4 guerriers) ou par individu ?
2. Brûlure du Mage : deux Mages sur la même cible → les brûlures **s'additionnent** ou se remplacent (actuel) ?
3. Cavalier « Cercle 1 » = les 8 cases autour de lui ?
4. En combat, chaque individu vise l'ennemi **le plus proche** : correct ?
5. En se déplaçant, un individu peut **traverser** une case occupée (actuel) ou doit la contourner ?
6. Gisements : **quantité** de chaque type (forêt, baies, métal, or) ? Récolte par tour du bois, de la
   nourriture et de l'or (2 comme le métal ?)
7. **Ouvrier** : PV et déplacement (actuel 30 PV, 2) ?
8. **Vision** des bâtiments (actuel 3) et du château ?
9. File de recrutement : limite ? Peut-on **annuler** (remboursé ?) ?
10. Sans nourriture : qui est servi en premier (actuel : bâtiments, puis escouades par ancienneté) ?
11. Boutons de la maquette : **bouclier**, les **2 icônes rondes** de la grille de commandes, **drapeau**
    (point de ralliement ?), les **4 onglets** à côté du portrait (tour, bannière, épées, étoile),
    onglet **Améliorations**, **Paramètres**, **Statistiques** : que font-ils ?
12. « Assiettes d'eau » : d'autres images à m'envoyer ?
13. Taille de la carte : assez grande ?

---

## 2. Prototype 4 — Jungle, monstres, boss, mines

### Monstres et animaux
Le pack contient : loup, loup alpha, ours, araignée, gobelin, gobelin archer, squelette, golem, ombre,
ombre errante, slime (« monstre »), mutant, jeune dragon, bandit, chef bandit, cultiste…

14. Quels monstres / animaux ? Pour chacun : **PV, dégâts, portée, déplacement, effectif** (groupe ?).
15. Lesquels donnent de l'**Organique** (animaux de la forêt) et combien ?
16. **Camps** (16 sur la carte) : composition de chaque camp ? Plus forts vers le centre ?
17. **Récompenses** des camps : or, organique, cartes (lesquelles ?) — directement en main ?
18. Les camps **réapparaissent**-ils ? Après combien de tours ?
19. **Comportement** : à quelle distance un monstre attaque-t-il ? Poursuit-il, puis rentre-t-il au camp ?
    Se soigne-t-il en rentrant ?

### Dragon (nord) et Sorcière (sud)
20. **Dragon** : PV, dégâts, portée, attaques spéciales (souffle de zone ?), comportement.
21. **Trésor du Dragon** : combien d'or ? « Améliorer la production d'or » : de combien, combien de temps ?
22. **Sorcière** : PV, dégâts, attaques ; **bénédictions** (lesquelles ?), **cartes puissantes** (lesquelles ?),
    **malédictions** (sur l'adversaire ?).
23. Les boss **réapparaissent**-ils ? Récompense pour un seul joueur (celui qui donne le coup final ?)

### Mines (5 : une centrale + 2 par côté)
24. **Production** par tour : or ? métal (« différents métaux » : lesquels ?) ? La mine centrale est-elle meilleure ?
25. **Capture** : comment ? (unités à côté pendant X tours ? tuer des gardiens ? aucune unité ennemie autour ?)
26. Une mine capturée est-elle **défendue** (gardes) ? Comment l'adversaire la **reprend**-il ?
27. Le document indique Mine : **75 Gd, 5 Bs, 3 Ml, 2 tours, 3 Nourri / tour** — c'est le coût pour
    **l'exploiter** après capture ? Pour en construire une sur un filon ?
28. Le **Mineur** « peut miner » : il travaille dans une mine capturée ? Il récolte plus vite ?

---

## 3. Prototype 5 — Mana et cartes (moteur déjà fait)

29. **Mana** : régénération par tour, maximum, mana de départ ?
30. **Cristaux de mana** : où sur la carte, combien ? **Bâtiment de mana** : coût, PV, bonus de régénération ?
31. **Liste des cartes** : pour chaque carte bonus / malus / neutre : nom, **coût en mana**, effet exact,
    usage unique ou non. (Les exemples du GDD sont déjà en jeu avec des coûts provisoires.)
32. **Destruction** : la carte détruite disparaît **définitivement** ou retourne sous le deck (actuel) ?
33. **Extension de main** : permanente ? **Nouvelle pioche** : on dépasse la limite (actuel) ?
34. **Malus** : lesquels **s'activent tout seuls** ? Quand (dès la pioche ? après X tours en main ?)
35. **Constitution du deck** : avant la partie, écran de choix des 10 bonus et des 5 malus pour l'adversaire ?
    Parmi quelle liste ?

---

## 4. Prototype 6 — Héros

36. Liste des héros : nom, classe (Tank, DPS, Mage, Support), **PV, dégâts, portée, déplacement**, sprite
    (le pack a : héros, capitaine, gardien, nécromancien, invocateur, druide, moine, prêtre, tacticien…).
37. **Cartes de capacités** de chaque héros (« le joueur récupère deux cartes associées ») : effets, coûts.
38. **Conditions d'invocation** : mana, ressources, condition particulière ?
39. **Évolution** : comment un héros progresse-t-il (niveaux, expérience) ?

---

## 5. Prototype 7 — Château, roi, défenses, siège

40. **Château** : PV, défense (attaque-t-il ?), taille, vision.
41. **Roi** : PV, dégâts, déplacement ; reste-t-il au château ? Victoire = château détruit **et** roi vaincu ?
42. **Défenses** (Tour Archer, Canon, Cabane Garde, Barricade, Mortier) : où peut-on les construire ?
    Faut-il des ouvriers ?
43. **Cabanes de garde** autour des bâtiments (Bank 5, Moulin 2, Entrepôt 3) : construites
    automatiquement ? Comment met-on des gardes dedans ?
44. **Murailles** : y en a-t-il (l'Échelle sert à les franchir ?) ? Barricade « 2 L » = 2 cases de long ?
45. **Machines de siège** : Échelle (1 unité) et Canon (2 unités) — les unités montent dedans ?
    Comment s'utilisent-elles ?

---

## 6. Prototype 8 — Multijoueur

46. Multijoueur **en ligne**, **sur le même écran**, ou contre une **IA** d'abord ?
