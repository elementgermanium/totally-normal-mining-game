class_name CraftingRecipe
extends Resource

@export var display_name: String
@export var inputs: Array[CraftingIngredient] = []
@export var outputs: Array[CraftingIngredient] = []
@export var time: float = 0.0
@export var station: BlockMaterial = null
