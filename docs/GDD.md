# GDD – PROJET RTS

**Version 0.2 – Document de conception initial**

> Document de référence. Toute mécanique ou valeur de gameplay implémentée doit en être issue
> (voir §15). Les points non définis sont listés au §13.

## 1. Présentation générale

### 1.1. Concept

Le projet est un jeu de stratégie en temps réel (RTS) opposant deux joueurs sur une carte commune.
Chaque joueur dirige un royaume qu'il doit développer économiquement, militairement et technologiquement afin de détruire le royaume adverse.

Le jeu combine plusieurs genres :

- **RTS** : gestion des armées, construction, économie et conquête.
- **MOBA** : jungle, rivière, monstres neutres et objectifs majeurs.
- **Deckbuilding** : utilisation de cartes pour modifier les possibilités stratégiques.
- **RPG** : héros spécialisés, capacités et évolutions.
- **Tower Defense** : fortifications et systèmes défensifs.
- **PvE** : exploration, monstres, boss et récompenses.

### 1.2. Objectif principal

Le but est de détruire le château adverse et de vaincre son roi.
Pour y parvenir, les joueurs doivent développer leur royaume, exploiter les ressources, construire leurs armées, contrôler la jungle et préparer des opérations militaires.

Le jeu se déroule intégralement en temps réel.
Les anciennes valeurs exprimées en tours servent uniquement de références pour définir les durées de production, de construction et de consommation. Elles devront être converties en secondes.

---

## 2. Structure de la carte

La carte comprend trois grandes zones.

### 2.1. Les royaumes

Chaque joueur possède son propre territoire. Il comprend :

- Un château.
- Un roi.
- Des bâtiments économiques.
- Des bâtiments militaires.
- Des infrastructures défensives.
- Des unités militaires.
- Des ouvriers.

Les joueurs peuvent agrandir leur royaume et développer leurs infrastructures.

### 2.2. La jungle

Une zone neutre sépare les deux royaumes. Elle contient :

- Des mines.
- Des ressources naturelles.
- Des monstres neutres.
- Des camps de créatures.
- Des objectifs secondaires.
- Des zones stratégiques.
- Des boss majeurs.

Une rivière et différents éléments géographiques structurent les déplacements et les affrontements.
La jungle constitue une zone de compétition permanente.

Les joueurs peuvent y envoyer des escouades pour :

- Exploiter des ressources.
- Combattre des monstres.
- Récupérer des cartes.
- Contrôler des objectifs.
- Préparer des attaques contre le territoire adverse.

### 2.3. Les objectifs majeurs

Deux boss principaux sont présents sur la carte.

**Le Dragon** possède un trésor. Sa défaite permet notamment :

- D'obtenir une importante quantité d'or.
- D'améliorer la production d'or.
- D'accélérer le développement économique.

**La Sorcière** possède des récompenses particulières. Elle peut notamment :

- Accorder des bénédictions.
- Ajouter des cartes puissantes à la main du joueur.
- Infliger des malédictions.
- Donner accès à des effets exceptionnels.

Les deux boss doivent proposer des récompenses différentes afin d'encourager des stratégies variées.

---

## 3. Système économique

Le jeu possède cinq ressources principales.

| Ressource | Abréviation | Utilisation |
|---|---|---|
| Or | Gd | Recrutement et constructions |
| Bois | Bs | Bâtiments et infrastructures |
| Métal / minerai | Ml | Défenses et équipements |
| Organique | O | Matériaux organiques |
| Nourriture | Nourri | Entretien et recrutement |

### 3.1. Production des ressources

Les joueurs doivent construire des infrastructures permettant de produire et de stocker leurs ressources.

**Bâtiments économiques connus**

| Bâtiment | PV | Capacité | Production |
|---|---|---|---|
| Bank | 250 | 2 000 Gd | 0 |
| Moulin | 100 | 100 Nourri | 0 |
| Entrepôt | 125 | 50 Bs, 25 Ml, 30 O | 0 |
| Culture | 50 | - | 10 Nourri |
| Ferme | 125 | - | 25 Nourri |
| Mine | À définir | - | À définir |

Les bâtiments possèdent :

- Un coût de construction.
- Un temps de construction.
- Une capacité de stockage éventuelle.
- Une production éventuelle.
- Une consommation alimentaire éventuelle.

### 3.2. Entretien

Certains bâtiments et certaines unités consomment de la nourriture.
Cette consommation est prélevée automatiquement sur les ressources du joueur à intervalles réguliers.
Si le joueur ne possède pas suffisamment de nourriture, les conséquences devront être définies.

### 3.3. Ouvriers

La cabane ouvrier permet d'obtenir deux ouvriers. Elle possède les caractéristiques suivantes :

- Coût : 2 Bs.
- Production : 3 Nourri par tour dans les règles initiales.

Les ouvriers permettent notamment :

- D'exploiter les ressources.
- De récolter les matériaux.
- De participer au développement économique.
- D'effectuer certaines constructions.

---

## 4. Système de mana

Le mana constitue une ressource stratégique distincte des ressources économiques classiques.
Il sert principalement à activer les cartes.

### 4.1. Régénération naturelle

Chaque joueur possède une production naturelle de mana.
Cette production fonctionne automatiquement en temps réel.
Les deux joueurs possèdent initialement exactement la même production de mana.
Le mana se régénère progressivement sans nécessiter de bâtiment particulier.
Les valeurs exactes de régénération restent à déterminer.

### 4.2. Amélioration de la production

Les joueurs peuvent améliorer leur production naturelle de mana. Plusieurs moyens sont prévus.

**Cristaux de mana** — Des cristaux peuvent être découverts et récoltés sur la carte.
Ils permettent de construire des bâtiments spécialisés qui augmentent la production de mana.
Ces bâtiments constituent un investissement économique permettant d'utiliser davantage de cartes au cours de la partie.

**Cartes Bonus** — Certaines cartes permettent d'augmenter temporairement la production de mana.
Exemple : une carte augmente la régénération de mana de 50 % pendant une durée déterminée.

**Autres sources** — Des récompenses de boss, des héros ou des bâtiments spéciaux pourront également influencer la production de mana. Ces possibilités restent à concevoir.

### 4.3. Utilisation du mana

Chaque carte possède un coût en mana.
Le joueur doit disposer d'une quantité suffisante de mana pour l'activer.
Le mana est consommé au moment de l'activation.

Le joueur doit donc choisir entre :

- Utiliser immédiatement ses cartes.
- Économiser son mana pour une carte plus puissante.
- Investir dans l'amélioration de sa production de mana.

Le mana crée ainsi une économie parallèle à celle des ressources classiques.

---

## 5. Système militaire

Les joueurs commandent des groupes d'unités appelés escouades.
Une escouade est une entité contrôlable unique composée de plusieurs individus.

### 5.1. Caractéristiques des unités

| Unité | Effectif | PV individuels | Dégâts individuels | Portée | Déplacement |
|---|---|---|---|---|---|
| Guerrier | 4 | 50 | 10 | 1 | 1 |
| Archer | 2 | 30 | 20 | 3 | 2 |
| Cavalier | 2 | 75 | 15 | Cercle 1 | 4 |
| Mage | 1 | 25 | 10 (+2/T) | Zone 2 | 1 |
| Soigneur | 1 | 35 | 5 | Zone 2, portée 3 | 2 |
| Mineur | 1 | 50 | 5 | 1 | 4 |

Les statistiques de PV et de dégâts sont individuelles.

**Précisions validées (après la v0.2)**

- **Mage** : 10 dégâts à l'impact, puis une brûlure de 2 dégâts à chaque tour pendant 2 tours.
- **Soigneur** : la valeur 5 est un **soin** (5 PV rendus), pas des dégâts. Zone 2, portée 3.
- **Mineur** : il peut combattre (5 dégâts) **et** miner.
- **Placement** : chaque individu occupe sa propre case (une escouade de 4 guerriers occupe 4 cases).

Exemple : une escouade de quatre guerriers possède initialement 200 PV au total et inflige 40 dégâts si les quatre guerriers attaquent simultanément.

Lorsqu'un individu meurt, il est retiré de l'escouade.
L'escouade continue d'exister tant qu'il reste des individus vivants.

### 5.2. Attaques de zone

Certaines unités possèdent des attaques de zone.
Le mage peut notamment attaquer deux cases horizontales ou deux cases verticales.
Les attaques de zone doivent respecter la géométrie et la portée définies pour chaque unité.
Les règles précises de ciblage devront être formalisées pendant le développement.

### 5.3. Production militaire

Les unités sont recrutées dans les bâtiments militaires.
Le joueur sélectionne l'unité à produire, paie son coût et attend la fin du recrutement.
Les unités ne sont jamais produites gratuitement.

Chaque unité possède :

- Un coût en ressources.
- Un temps de production.
- Un effectif par escouade.

Les productions ne sont pas toutes réalisées simultanément dans une même file de recrutement.

---

## 6. Bâtiments militaires et défenses

Les bâtiments défensifs permettent de protéger le royaume et de ralentir les attaques adverses.

| Défense | PV | Dégâts | Portée |
|---|---|---|---|
| Tour Archer | 100 | 20 | 7 |
| Canon | 150 | 40 | 4 |
| Cabane Garde | 2 × 50 | 2 × 10 | 3 |
| Barricade | 50 | 0 | 2 cases |
| Mortier | 125 | 30 | 2 à 6 |

Chaque défense possède un coût et un temps de construction.

### 6.1. Machines de siège

Deux machines sont actuellement prévues.

| Machine | PV | Dégâts | Portée | Capacité |
|---|---|---|---|---|
| Échelle | 0 | 0 | 1 | 1 unité |
| Canon | 75 | 75 | 1 | 2 unités |

Elles servent à faciliter les assauts contre les fortifications adverses.

---

## 7. Système de cartes

Le système de cartes constitue l'une des principales particularités du jeu.
Il permet de personnaliser les possibilités stratégiques du joueur. Il existe quatre catégories.

### 7.1. Cartes Bonus

Elles permettent d'obtenir des avantages économiques, militaires ou technologiques. Elles peuvent notamment :

- **Débloquer des bâtiments** : banques spécialisées, entrepôts améliorés, infrastructures particulières, bâtiments augmentant la production de mana.
- **Améliorer les unités** : augmentation des dégâts, augmentation des PV, amélioration des déplacements, capacités supplémentaires.
- **Améliorer l'économie** : augmentation de la production, réduction de certains coûts, obtention de ressources immédiates.
- **Modifier la production de mana** : augmentation temporaire de la régénération, production supplémentaire, effets particuliers liés aux cristaux.

Exemple : une carte permet de recevoir immédiatement 200 Gd.

### 7.2. Cartes Malus

Les cartes malus sont des cartes négatives intégrées au deck du joueur.
Elles sont principalement choisies par l'adversaire lors de la constitution initiale du deck.

Elles peuvent :

- S'activer automatiquement.
- Nécessiter une activation manuelle.
- Imposer des contraintes économiques.
- Affaiblir certaines unités.
- Perturber les bâtiments.
- Réduire certaines capacités.

**Occupation de la main** — Les cartes malus occupent des emplacements dans la main.
Le joueur peut choisir de ne pas les activer, mais elles réduisent ses possibilités de jeu.

| Composition de la main | Cartes exploitables |
|---|---|
| 3 cartes normales | 3 |
| 2 normales + 1 malus | 2 |
| 1 normale + 2 malus | 1 |

Cette mécanique force le joueur à arbitrer entre subir un effet négatif et conserver une carte morte.

**Malus classiques** — Lorsqu'elles sont activées :

- Leur effet négatif est appliqué.
- Elles retournent sous le deck.
- Le joueur pioche pour compléter sa main.

**Malus exceptionnels** — Certaines malédictions sont particulièrement puissantes.
Elles peuvent notamment être obtenues auprès de la Sorcière. Lorsqu'elles sont activées :

- Leur effet est appliqué.
- La carte disparaît définitivement.
- La malédiction peut continuer à produire des effets persistants.

### 7.3. Cartes Neutres

Les cartes neutres sont accessibles aux deux joueurs. Elles sont obtenues :

- Au début de la partie.
- Dans les monstres.
- Dans la jungle.
- Dans certaines mines.
- En accomplissant des objectifs.

Elles permettent de modifier les règles ou les possibilités du joueur. Exemples :

| Carte | Effet |
|---|---|
| Extension de main | Augmente la limite de cartes |
| Destruction | Détruit une carte de sa main |
| Bannissement | Retire définitivement une carte malus |
| Nouvelle pioche | Permet de piocher une carte supplémentaire |

### 7.4. Cartes Héros

Les héros constituent une catégorie particulière.
Une carte héros permet d'invoquer une véritable unité sur le champ de bataille.
Le héros devient une unité contrôlable. Il peut :

- Se déplacer.
- Combattre.
- Utiliser ses capacités.
- Participer aux affrontements.
- Interagir avec certains bâtiments et objectifs.

**Capacités des héros** — Les cartes associées au héros représentent ses capacités. Exemples :
charge, attaque puissante, sort de zone, protection, soin, invocation de créatures, amélioration des infrastructures.

Lorsqu'un héros est invoqué, le joueur récupère deux cartes associées à ce héros et choisit celles qu'il souhaite ajouter à sa main. Les autres retournent dans le deck.
Les héros peuvent évoluer et débloquer de nouvelles capacités.

**Conditions d'invocation** — Chaque héros possède ses propres conditions. Elles peuvent comprendre :
un coût en mana, un coût en ressources, une condition particulière, plusieurs conditions combinées.

**Mort des héros** — Lorsqu'un héros meurt :

- Il est retiré du champ de bataille.
- Sa carte retourne dans le deck.
- Il pourra être invoqué de nouveau si les conditions sont remplies.

Chaque joueur peut sélectionner au maximum trois héros différents dans son deck.

---

## 8. Classes de héros

Quatre classes principales sont prévues.

| Classe | Fonction | Exemples |
|---|---|---|
| Tank | Protection et résistance | Gardien |
| DPS physique | Dégâts physiques | Guerrier, archer |
| Mage | Pouvoirs magiques | Nécromancien, mage de foudre |
| Support | Assistance et améliorations | Soigneur, mécanicien |

Les héros ne sont pas obligés de participer directement aux combats.
Un héros mécanicien peut notamment :

- Débloquer des améliorations de bâtiments.
- Réduire les coûts de construction.
- Améliorer les machines de siège.
- Développer de nouvelles technologies.

Les héros doivent influencer le gameplay de manière différente selon leur spécialisation.

---

## 9. Composition et gestion du deck

Chaque joueur commence avec un deck de 20 cartes.

| Catégorie | Quantité |
|---|---|
| Bonus | 10 |
| Malus | 5 |
| Neutres | 5 |
| **Total** | **20** |

**Constitution**

- Le joueur choisit ses 10 cartes bonus.
- L'adversaire choisit ses 5 cartes malus.
- Les 5 cartes neutres sont générées aléatoirement.
- Les deux joueurs possèdent les mêmes cartes neutres.

**Main initiale** — Chaque joueur commence avec trois cartes. La limite normale de la main est de trois cartes.

**Utilisation des cartes** — Lorsqu'une carte classique est utilisée :

1. Le coût en mana est payé.
2. L'effet est appliqué.
3. La carte retourne sous le deck.
4. Le joueur pioche pour compléter sa main.

Les cartes à utilisation unique disparaissent définitivement après activation.

**Cartes obtenues sur le terrain** — Certaines récompenses sont directement ajoutées à la main du joueur. Elles ne sont pas ajoutées au deck. Cela concerne notamment :
les bénédictions, les malédictions, certaines cartes de boss, certaines récompenses de monstres, des cartes spéciales découvertes dans la jungle.

**Bannissement** — Certaines cartes permettent de retirer définitivement une carte du deck.
Cela permet de réduire progressivement le nombre de malus.

---

## 10. Archétypes et spécialisations

Pour le premier prototype, les deux joueurs utilisent le même deck de base.
À terme, plusieurs archétypes pourront être proposés. Chaque archétype possédera :
ses propres cartes bonus, ses propres cartes malus, ses propres héros, ses propres capacités, ses propres avantages économiques ou militaires.

| Archétype | Spécialisation |
|---|---|
| Empire industriel | Production et construction |
| Royaume militaire | Armées et sièges |
| Royaume magique | Magie et mana |
| Royaume défensif | Fortifications |
| Royaume économique | Accumulation de ressources |

Chaque archétype doit offrir une expérience stratégique différente.

---

## 11. Déroulement d'une partie

1. **Développement initial** — Les joueurs construisent leurs premières infrastructures, exploitent leurs ressources et produisent leurs premières unités.
2. **Exploration** — Les joueurs envoient leurs escouades dans la jungle pour découvrir des ressources, des mines et des camps de monstres.
3. **Confrontation** — Les joueurs commencent à se disputer les zones stratégiques, les ressources et les objectifs neutres.
4. **Spécialisation** — Les joueurs utilisent leurs cartes, invoquent leurs héros et développent leurs stratégies économiques et militaires.
5. **Objectifs majeurs** — Les joueurs tentent de vaincre le Dragon et la Sorcière pour obtenir leurs récompenses.
6. **Guerre** — Les joueurs organisent des raids, défendent leurs territoires et préparent leurs sièges.
7. **Victoire** — Le joueur qui parvient à détruire le château adverse et à vaincre son roi remporte la partie.

---

## 12. Principes fondamentaux de conception

1. Le jeu est intégralement en temps réel.
2. Les unités militaires fonctionnent sous forme d'escouades.
3. Les PV et dégâts sont individuels.
4. Les pertes militaires sont permanentes, sauf mécanique particulière.
5. L'économie est fondamentale.
6. La jungle constitue une zone stratégique majeure.
7. Les boss apportent des récompenses significatives.
8. Les cartes influencent directement les possibilités de jeu.
9. Les héros sont des unités physiques contrôlables.
10. Les cartes héros représentent leurs capacités.
11. Les héros morts retournent dans le deck.
12. Le mana se régénère automatiquement.
13. Les deux joueurs possèdent initialement la même régénération naturelle de mana.
14. La production de mana peut être améliorée grâce aux cristaux, bâtiments et cartes.
15. Les cartes malus peuvent encombrer la main.
16. Certaines cartes peuvent être bannies définitivement.
17. Les joueurs peuvent développer des stratégies économiques et militaires différentes.
18. Le jeu doit rester modulaire et évolutif.

---

## 13. Éléments restant à définir

Ces éléments ne doivent pas être inventés arbitrairement pendant le développement.

| Système | Éléments à définir |
|---|---|
| Temps | Durées réelles des constructions et productions |
| Déplacement | Vitesse réelle des unités |
| Mana | Régénération initiale et capacité maximale |
| Cristaux | Répartition et quantité sur la carte |
| Boss | PV, dégâts, comportements et récompenses |
| Mines | Production et exploitation |
| Château | PV, défense et conditions de destruction |
| Roi | Statistiques et comportement |
| Héros | Capacités, coûts et conditions d'invocation |
| Deck | Détails des effets des cartes |
| Multijoueur | Architecture et synchronisation |
| Carte | Dimensions, génération et obstacles |
| IA | Comportement des monstres neutres |

---

## 14. Plan de développement du prototype

Le développement doit se faire progressivement.
L'objectif n'est pas de produire immédiatement le jeu complet, mais d'obtenir rapidement une version jouable sur laquelle tester les mécaniques.

| Version | Contenu |
|---|---|
| Prototype 1 | Carte, déplacements, sélection et combats |
| Prototype 2 | Ressources, ouvriers et constructions |
| Prototype 3 | Recrutement et gestion des escouades |
| Prototype 4 | Jungle, monstres et boss |
| Prototype 5 | Mana et système de cartes |
| Prototype 6 | Héros et capacités |
| Prototype 7 | Sièges et conditions de victoire |
| Prototype 8 | Multijoueur et équilibrage |

### Architecture recommandée

Le projet sera développé avec Godot 4. Il devra être organisé de manière modulaire.
Les systèmes devront être indépendants autant que possible :

- Gestion des unités.
- Gestion des combats.
- Gestion des bâtiments.
- Gestion des ressources.
- Gestion du mana.
- Gestion des cartes.
- Gestion des héros.
- Gestion de la carte.
- Gestion des monstres.
- Gestion du multijoueur.

Les unités, bâtiments, cartes et héros devront idéalement être définis à partir de données configurables plutôt que codés individuellement dans des scripts spécifiques.
Cela permettra d'ajouter du contenu sans devoir réécrire les systèmes fondamentaux.

---

## 15. Direction de développement avec Claude

Pour le développement par vibe coding, quelques règles sont importantes. Claude doit respecter les règles suivantes :

1. Ne pas inventer de mécaniques de gameplay sans validation.
2. Ne pas modifier les valeurs définies sans autorisation.
3. Ne pas supprimer une fonctionnalité existante pour en remplacer une autre sans justification.
4. Privilégier une architecture modulaire.
5. Éviter les scripts monolithiques.
6. Documenter les systèmes importants.
7. Séparer les données du fonctionnement des mécaniques.
8. Prévoir l'ajout futur de nouveaux bâtiments, unités, cartes et héros.
9. Tester chaque système avant de passer au suivant.
10. Ne pas commencer le système complet avant d'avoir validé les fondations du prototype.

**Priorité absolue : obtenir un RTS fonctionnel avant d'ajouter toutes les mécaniques secondaires.**

---

## Notes de l'auteur — points de vigilance

1. **Le mana et les cartes** — C'est un système qui peut rapidement devenir très puissant. Il faudra éviter qu'un joueur ayant pris de l'avance sur la production de mana puisse enchaîner les cartes sans véritable contrepartie.
2. **Les héros** — Ils doivent être suffisamment intéressants pour justifier leur place dans une armée, mais leur mort ne doit pas être une sanction tellement lourde qu'elle décourage leur utilisation.
3. **Le contrôle de la jungle** — C'est probablement le cœur de la partie. Si la jungle est trop peu intéressante, les joueurs resteront dans leurs bases à développer leurs économies. Si elle est trop rentable, les affrontements dans les royaumes perdront leur importance.
