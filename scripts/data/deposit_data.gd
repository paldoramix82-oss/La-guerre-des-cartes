class_name DepositData
extends Resource
## Type de gisement récoltable par les ouvriers (récolte sur place, gisement épuisable).
## L'or et le métal viennent des mines (inépuisables), pas des gisements.

@export var id: StringName
@export var display_name: String = ""
## Ressource produite (voir ResourceTypes).
@export var resource: StringName = ResourceTypes.WOOD
## Quantité totale avant épuisement.
@export var amount: int = 0
## Récolte d'un ouvrier par tour.
@export var harvest_per_turn: int = 10
@export var sprite: Texture2D
@export_multiline var design_notes: String = ""
