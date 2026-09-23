class_name Subworld
extends Node2D

@export var spawnpoint := Vector2.ZERO
@export var world_id: String
var block_overrides: Dictionary = {}
var initialized = false

func enter_world(new_player: CharacterBody2D):
	new_player.global_position = spawnpoint

func exit_world():
	pass

func initialize_world():
	initialized = true

var player: CharacterBody2D

func set_player(new_player: CharacterBody2D):
	player = new_player

func get_runtime_state() -> Dictionary:
	return {"block_overrides": get_save_data()}

func load_runtime_state(state: Dictionary):
	load_save_data(state.get("block_overrides", []))

func get_save_data() -> Array:
	var data = []
	for location in block_overrides:
		var block_material = block_overrides[location]
		data.append({"x": location.x, "y": location.y, "material": block_material.resource_path})
	return data

func load_save_data(data: Array):
	block_overrides.clear()
	for entry in data:
		var location = Vector2i(int(entry["x"]), int(entry["y"]))
		var block_material = load(entry["material"])
		block_overrides[location] = block_material
