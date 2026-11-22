class_name ResourceTypes
extends RefCounted
## Les cinq ressources du jeu (GDD §3). Les coûts, capacités, productions et
## consommations sont des Dictionary {identifiant: quantité} utilisant ces clés.

const GOLD := &"gold"       ## Or (Gd)
const WOOD := &"wood"       ## Bois (Bs)
const METAL := &"metal"     ## Métal / minerai (Ml)
const ORGANIC := &"organic" ## Organique (O)
const FOOD := &"food"       ## Nourriture (Nourri)
const CRYSTAL := &"crystal" ## Cristaux de mana (créatures magiques) : bâtiments de mana

const ALL: Array[StringName] = [GOLD, WOOD, METAL, ORGANIC, FOOD, CRYSTAL]

const ABBREVIATIONS := {GOLD: "Gd", WOOD: "Bs", METAL: "Ml", ORGANIC: "O", FOOD: "Nourri", CRYSTAL: "Cristaux"}
const NAMES := {GOLD: "Or", WOOD: "Bois", METAL: "Métal", ORGANIC: "Organique", FOOD: "Nourriture", CRYSTAL: "Cristaux de mana"}


## Texte lisible d'une quantité de ressources, ex. « 200 Gd, 10 Bs, 5 Ml ».
static func format(amounts: Dictionary) -> String:
	var parts: Array[String] = []
	for r in ALL:
		if amounts.get(r, 0) != 0:
			parts.append("%d %s" % [amounts[r], ABBREVIATIONS[r]])
	return ", ".join(parts) if not parts.is_empty() else "—"
