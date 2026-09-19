extends CharacterBody2D

var inventory: Dictionary = {}
@export var SPEED := 300.0
const JUMP_VELOCITY = -400.0
var mining_range = 250
var mining_target = null
var mining_progress: float = 0.0
var placement_range = 250

@onready var inventory_label = $"../UI/InventoryLabel"
@onready var mining_bar = $"../UI/MiningProgress"
@onready var world = $"../Blocks"

var half_block = 32

func update_inventory_display():
	var text = "Inventory:\n"
	for item in inventory:
		text += item.material_name + ": " + str(inventory[item]) + "\n"
		inventory_label.text = text

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func get_mining_target():
	var mouse_position = get_global_mouse_position()
	
	if global_position.distance_to(mouse_position) > mining_range:
		return
	
	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_position
	query.collide_with_bodies = true
	
	var results = get_world_2d().direct_space_state.intersect_point(query)
	if results.size() > 0:
		var target = results[0]["collider"]
		if target.has_method("mine"):
			return target
	return null

func add_item(item: BlockMaterial, amount: int = 1):
	if inventory.has(item):
		inventory[item] += amount
	else:	
		inventory[item] = amount
	update_inventory_display()

func print_inventory():
	print("INVENTORY: ")
	for item in inventory:
		print(item.material_name, ": ", inventory[item])

func _process(delta):
	if Input.is_action_pressed("mine"):
		continue_mining(delta)
	else:
		stop_mining()
	if Input.is_action_just_pressed("use_item"):
		var mouse_position = get_global_mouse_position()
		var target = get_mouse_block_position()
		var current_block = world.get_material_at(target)
		if global_position.distance_to(mouse_position) <= placement_range:
			if current_block == world.air:
				if inventory[world.dirt] > 0:
					world.place_block(target, world.dirt)
					inventory[world.dirt] -= 1
					update_inventory_display()

func get_mouse_block_position() -> Vector2i:
	var mouse_position = get_global_mouse_position()
	return Vector2i(floori((mouse_position.x + half_block) / world.BLOCK_SIZE), floori((mouse_position.y + half_block) / world.BLOCK_SIZE) - 2)

func continue_mining(delta):
	var target = get_mining_target()
	
	if target == null:
		stop_mining()
		return
	
	if target != mining_target:
		mining_target = target
		mining_progress = 0.0
	
	mining_progress += delta
	mining_bar.value = mining_progress / mining_target.block_material.mining_time
	mining_bar.visible = true
	
	if mining_progress >= mining_target.block_material.mining_time:
		finish_mining()

func stop_mining():
	mining_target = null
	mining_progress = 0.0
	mining_bar.visible = false

func finish_mining():
	var block_position = mining_target.world_position
	world.mark_block_mined(block_position)
	var loot = mining_target.mine()
	add_item(loot)
	stop_mining()

func get_player_save_data() -> Array:
	var data = []
	for item in inventory:
		data.append({"item": item.resource_path, "amount": inventory[item]})
	return data

func load_player_save_data(data: Array):
	inventory.clear()
	for entry in data:
		var item = load(entry["item"])
		var amount = int(entry["amount"])
		inventory[item] = amount
	update_inventory_display()
