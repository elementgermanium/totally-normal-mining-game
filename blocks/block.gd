class_name Block
extends StaticBody2D


var block_material: BlockMaterial
var world_position: Vector2i

func set_block_material(new_material: BlockMaterial):
	block_material = new_material
	$Sprite2D.modulate = block_material.color



func mine() -> BlockMaterial:
	var mined_material = block_material
	queue_free()
	return mined_material
