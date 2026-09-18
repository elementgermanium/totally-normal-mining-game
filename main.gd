extends Node2D

@onready var world = $"Blocks"
@onready var player = $"Player"

const SAVE_PATH := "user://save.json"


# Called when the node enters the scene tree for the first time.
func _ready():
	load_game()
	world.initialize_ores()
	world.initialize_chunks()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta) -> void:
	pass

func save_game():
	var save_data = {
		"save_version" = 1,
		"player_x" = player.global_position.x,
		"player_y" = player.global_position.y,
		"inventory" = player.get_player_save_data(),
		"block overrides" = world.get_save_data(),
		"seed" = world.world_seed
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
		print("Save file couldn't be read!")
		return
	var version = int(save_data.get("save_version", 0))
	if version != 1:
		push_error("Unsupported save version: " + str(version))
	player.global_position = Vector2(float(save_data["player_x"]), float(save_data["player_y"]))
	player.load_player_save_data(save_data["inventory"])
	world.load_save_data(save_data["block overrides"])
	world.world_seed = int(save_data.get("seed", 12345))
	print("World loaded!")
	
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

func _unhandled_input(event):
	if event.is_action_pressed("manual_save"):
		save_game()
