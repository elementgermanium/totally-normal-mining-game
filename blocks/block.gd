class_name Block
extends StaticBody2D


var block_material: BlockMaterial
var world_position: Vector2i

func set_block_material(new_material: BlockMaterial):
	block_material = new_material
	$Sprite2D.modulate = block_material.color



func mine() -> Item:
	var drop
	if block_material.drops_self == true:
		drop = block_material
	else:
		drop = block_material.dropped_item
	queue_free()
	return drop
