extends Node2D

@onready var player = $"Player"
@export var earth_scene: PackedScene
@export var base_scene: PackedScene

const SAVE_PATH := "user://save.json"
const CURRENT_SAVE_VERSION = 3
var current_world: Subworld
var world_states: Dictionary = {}
var world_player_positions: Dictionary = {}


# Called when the node enters the scene tree for the first time.
func _ready():
	if FileAccess.file_exists(SAVE_PATH):
		load_game()
	else:
		start_new_game()
	player.initialize_hotbar_ui()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta) -> void:
	pass

func start_new_game():
	current_world = earth_scene.instantiate()
	$WorldContainer.add_child(current_world)
	current_world.set_player(player)
	player.set_current_world(current_world)
	current_world.enter_world(player)
	current_world.initialize_world()

func serialize_world_player_positions() -> Dictionary:
	var data := {}
	for world_id in world_player_positions:
		var location: Vector2 = world_player_positions[world_id]
		data[world_id] = [location.x, location.y]
	return data

func deserialize_world_player_positions(data: Dictionary):
	world_player_positions.clear()
	for world_id in data:
		var position_data = data[world_id]
		world_player_positions[world_id] = Vector2(float(position_data[0]), float(position_data[1]))

func save_game():
	world_states[current_world.world_id] = current_world.get_runtime_state()
	world_player_positions[current_world.world_id] = player.global_position
	var save_data = {
		"save_version" = CURRENT_SAVE_VERSION,
		"current_world" = current_world.world_id,
		"world_states" = world_states,
		"world_player_positions" = serialize_world_player_positions(),
		"inventory" = player.get_player_save_data(),
		"hotbar" = player.get_hotbar_save_data(),
		"selected_slot" = player.selected_slot,
		"equipped_tool" = player.save_equipped_item()
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	print("Game saved!")

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file exists. Creating a new world...")
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var save_data = JSON.parse_string(file.get_as_text())
	if save_data == null:
		push_error("Save file couldn't be read!")
		return
	if not save_data is Dictionary:
		push_error("Save format corrupt/unreadable!")
	var version = int(save_data.get("save_version", 0))
	if version > CURRENT_SAVE_VERSION:
		push_error("Are you from the future? Current save version is " + str(CURRENT_SAVE_VERSION))
		return
	save_data = migrate_save(save_data)
	if save_data.is_empty():
		push_error("Save migration failed!")
		return
	load_save_data(save_data)

func load_save_data(data: Dictionary):
	world_states = data.get("world_states", {}).duplicate(true)
	deserialize_world_player_positions(data.get("world_player_positions", {}))
	var hotbar_data = data.get("hotbar", [])
	player.load_player_save_data(data["inventory"])
	player.load_hotbar_save_data(hotbar_data)
	player.selected_slot = int(data.get("selected_slot", 0))
	player.load_equipped_tool(data["equipped_tool"])
	var saved_world_id = str(data.get("current_world", "Earth"))
	load_saved_world(saved_world_id)
	print("World loaded!")

func load_saved_world(world_id: String):
	var world_scene = get_world_scene(world_id)
	if world_scene == null:
		push_error("Unknown world ID: " + world_id)
		return
	current_world = world_scene.instantiate()
	$WorldContainer.add_child(current_world)
	current_world.set_player(player)
	player.set_current_world(current_world)
	if world_states.has(world_id):
		current_world.load_runtime_state(world_states[world_id])
	if world_player_positions.has(world_id):
		player.global_position = world_player_positions[world_id]
	else:
		current_world.enter_world(player)
	current_world.initialize_world()

func get_world_scene(world_id: String) -> PackedScene:
	match world_id:
		"Earth":
			return earth_scene
		"Base":
			return base_scene
		_:
			return null

func migrate_save(data: Dictionary) -> Dictionary:
	var version = int(data.get("save_version", 1))
	while version < CURRENT_SAVE_VERSION:
		match version:
			1:
				data = migrate_v1_v2(data)
			2:
				data = migrate_v2_v3(data)
			_:
				push_error("Cannot migrate save version: " + version)
				return {}
		version = int(data["save_version"])
	return data

func migrate_v1_v2(data: Dictionary) -> Dictionary:
	var new_inventory = []
	for old_entry in data["inventory"]:
		new_inventory.append(
			{"item": old_entry["item"],
			"amount": int(old_entry["amount"])}
		)
	data["inventory"] = new_inventory
	data["save_version"] = 2
	print("Successfully migrated save to v2")
	return data

func migrate_v2_v3(data: Dictionary) -> Dictionary:
	var old_position = [data.get("player_x", 0.0), data.get("player_y", 0.0)]
	data["current_world"] = "Earth"
	data["world_states"] = {
		"Earth": {
			"seed": data.get("seed", 0),
			"block_overrides": data.get("block overrides", [])
		}
		}
	data["world_player_positions"] = {
		"Earth": old_position
	}
	data.erase("seed")
	data.erase("block overrides")
	data.erase("player_x")
	data.erase("player_y")
	data["save_version"] = 3
	return data

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

func _unhandled_input(event):
	if event.is_action_pressed("manual_save"):
		save_game()
	if event.is_action_pressed("basetp"):
		change_world(base_scene)
	if event.is_action_pressed("earthtp"):
		change_world(earth_scene)

func unload_current_world():
	if current_world == null:
		return
	world_states[current_world.world_id] = current_world.get_runtime_state()
	current_world.queue_free()
	current_world = null

func change_world(world_scene: PackedScene):
	world_player_positions[current_world.world_id] = $Player.global_position
	unload_current_world()
	current_world = world_scene.instantiate()
	$WorldContainer.add_child(current_world)
	player.set_current_world(current_world)
	current_world.set_player(player)
	if world_states.has(current_world.world_id):
		current_world.load_runtime_state(world_states[current_world.world_id])
	if world_player_positions.has(current_world.world_id):
		$Player.global_position = world_player_positions[current_world.world_id]
	else:
		current_world.enter_world($Player) 
	current_world.initialize_world()
