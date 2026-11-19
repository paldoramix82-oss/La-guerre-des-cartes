class_name CardData
extends Resource
## Définition data-driven d'une carte (GDD §7). Une nouvelle carte s'ajoute en
## créant un fichier .tres dans res://data/cards/.

## Catégories du GDD §7.
enum Category {
	BONUS,   ## Avantages économiques, militaires, technologiques (§7.1)
	MALUS,   ## Cartes négatives choisies par l'adversaire, encombrent la main (§7.2)
	NEUTRAL, ## Modifient les règles du joueur, communes aux deux joueurs (§7.3)
	HERO,    ## Invoquent un héros (§7.4, Prototype 6)
}

## Effets disponibles. Les paramètres sont dans `params`.
enum Effect {
	NONE,             ## Aucun effet (malus d'exemple, effet à définir)
	GAIN_RESOURCES,   ## params.resources : {ressource: quantité}, reçues immédiatement
	MANA_REGEN_BOOST, ## params.multiplier (ex. 1.5 = +50 %), params.turns : durée
	HAND_LIMIT_UP,    ## params.amount : augmente la limite de la main
	DESTROY_HAND_CARD,## Choisir une carte de sa main : elle quitte la main
	BANISH_MALUS,     ## Choisir une carte malus de sa main : retirée définitivement
	DRAW_CARDS,       ## params.amount : pioche supplémentaire
}

@export var id: StringName
@export var display_name: String = ""
@export var category: Category = Category.BONUS
@export var mana_cost: int = 0
@export var effect: Effect = Effect.NONE
@export var params: Dictionary = {}
## Disparaît définitivement après activation (au lieu de retourner sous le deck).
@export var single_use: bool = false
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_multiline var design_notes: String = ""


## L'activation demande de choisir une autre carte de la main.
func needs_hand_target() -> bool:
	return effect == Effect.DESTROY_HAND_CARD or effect == Effect.BANISH_MALUS
