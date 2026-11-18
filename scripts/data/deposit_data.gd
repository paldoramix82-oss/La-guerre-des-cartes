class_name DepositData
extends Resource
## Type de gisement récoltable par les ouvriers (récolte sur place, gisement épuisable).

@export var id: StringName
@export var display_name: String = ""
## Ressource produite (voir ResourceTypes).
@export var resource: StringName = ResourceTypes.WOOD
## Quantité totale avant épuisement.
@export var amount: int = 0
@export var sprite: Texture2D
@export_multiline var design_notes: String = ""
