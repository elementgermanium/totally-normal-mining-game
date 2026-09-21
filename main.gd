extends Node2D

@onready var world = $"Blocks"
@onready var player = $"Player"

const SAVE_PATH := "user://save.json"
const CURRENT_SAVE_VERSION = 2


# Called when the node enters the scene tree for the first time.
func _ready():
	load_game()
	world.initialize_layers()
	world.initialize_ores()
	world.initialize_chunks()
	player.initialize_hotbar_ui()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta) -> void:
	pass

func save_game():
	var save_data = {
		"save_version" = CURRENT_SAVE_VERSION,
		"player_x" = player.global_position.x,
		"player_y" = player.global_position.y,
		"inventory" = player.get_player_save_data(),
		"block overrides" = world.get_save_data(),
		"seed" = world.world_seed,
		"hotbar" = player.get_hotbar_save_data(),
		"selected_slot" = player.selected_slot
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
	var version = int(save_data.get("save_version", 0))
	if save_data == null:
		print("Save file couldn't be read!")
		return
	if version > CURRENT_SAVE_VERSION:
		print("Are you from the future? Current save version is " + str(CURRENT_SAVE_VERSION))
	save_data = migrate_save(save_data)
	if save_data.is_empty():
		return
	var hotbar_data = save_data.get("hotbar", [])
	player.global_position = Vector2(float(save_data["player_x"]), float(save_data["player_y"]))
	player.load_player_save_data(save_data["inventory"])
	world.load_save_data(save_data["block overrides"])
	player.load_hotbar_save_data(hotbar_data)
	player.selected_slot = int(save_data.get("selected_slot", 0))
	world.world_seed = int(save_data.get("seed", 12345))
	print("World loaded!")
	
func migrate_save(data: Dictionary) -> Dictionary:
	var version = int(data.get("save_version", 1))
	while version < CURRENT_SAVE_VERSION:
		match version:
			1:
				data = migrate_v1_v2(data)
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

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

func _unhandled_input(event):
	if event.is_action_pressed("manual_save"):
		save_game()
