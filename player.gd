extends CharacterBody2D

var inventory: Array[InventorySlot] = []
@export var SPEED := 300.0
const JUMP_VELOCITY = -400.0
var mining_range = 250
var mining_target = null
var mining_progress: float = 0.0
var mining_power: float = 1.0
var placement_range = 250
var selected_slot: int = 0
var hotbar: Array[Item] = []
const HOTBAR_SIZE = 10
var equipped_tool: Tool = null

@onready var mining_bar = $"../UI/MiningProgress"
@onready var world = $"../Blocks"
@onready var hotbar_ui = $"../UI/Hotbar"
@onready var inventory_menu = $"../UI/InventoryMenu"
@onready var inventory_list = $"../UI/InventoryMenu/ScrollContainer/InventoryList"
@onready var equipment_label = $"../UI/InventoryMenu/ToolLabel"

var hotbar_slot_scene = preload("res://UI/hotbar_slot.tscn")
var inventory_entry_scene = preload("res://UI/inventory_entry.tscn")
var half_block = 32

func initialize_hotbar_ui():
	for i in range(HOTBAR_SIZE):
		var slot_ui = hotbar_slot_scene.instantiate()
		hotbar_ui.add_child(slot_ui)
	update_hotbar_display()

func get_item_amount(item: Item) -> int:
	for slot in inventory:
		if slot.item == item:
			return slot.amount
	return 0

func update_hotbar_display():
	for i in range(HOTBAR_SIZE):
		var slot_ui = hotbar_ui.get_child(i)
		var item = hotbar[i]
		slot_ui.set_selected(i == selected_slot)
		if item == null:
			slot_ui.display_item(null, 0)
		else:
			slot_ui.display_item(item, get_item_amount(item))

func update_inventory_menu():
	for child in inventory_list.get_children():
		child.queue_free()
	for slot in inventory:
		var entry = inventory_entry_scene.instantiate()
		inventory_list.add_child(entry)
		entry.setup(slot.item, slot.amount)
		entry.pressed.connect(func(): use_inventory_item(slot.item))
	update_equipment_display()

func use_inventory_item(item: Item):
	if item is Tool:
		equip_tool(item)
	else:
		assign_item_to_hotbar(item)

func assign_item_to_hotbar(item: Item):
	hotbar[selected_slot] = item
	update_hotbar_display()

func equip_tool(item: Tool):
	if equipped_tool == item:
		equipped_tool = null
		mining_power = 1
	else:
		equipped_tool = item
		mining_power = equipped_tool.power
	update_inventory_menu()

func update_equipment_display():
	if equipped_tool == null:
		equipment_label.text = "Tool: None"
	else:
		equipment_label.text = "Tool: " + equipped_tool.item_name

func toggle_inventory():
	inventory_menu.visible = not inventory_menu.visible
	if inventory_menu.visible:
		update_inventory_menu()

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

func add_item(item: Item, amount: int = 1):
	for slot in inventory:
		if slot.item == item:
			slot.amount += amount
			update_hotbar_display()
			return
	var new_slot = InventorySlot.new(item, amount)
	inventory.append(new_slot)

func get_selected_item() -> Item:
	return hotbar[selected_slot]

func hotbar_left():
	selected_slot = (selected_slot + 1) % HOTBAR_SIZE
	update_hotbar_display()

func hotbar_right():
	selected_slot = posmod(selected_slot - 1, HOTBAR_SIZE)
	update_hotbar_display()

func print_inventory():
	print("INVENTORY: ")
	for item in inventory:
		print(item.material_name, ": ", inventory[item])

func remove_item(item: Item, amount: int = 1) -> bool:
	for i in range(inventory.size()):
		var slot = inventory[i]
		if slot.item == item:
			if slot.amount < amount:
				return false
			slot.amount -= amount
			if slot.amount <= 0:
				inventory.remove_at(i)
				if selected_slot >= inventory.size():
					selected_slot = max(0, inventory.size() - 1)
			update_hotbar_display()
			return true
	return false

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
				var selected_item = get_selected_item()
				if selected_item == null:
					return
				if selected_item is not BlockMaterial:
					return
				if get_item_amount(selected_item) <= 0:
					return
				var can_place = remove_item(selected_item)
				if can_place == true:
					world.place_block(target, selected_item)

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("inventory_down"):
		hotbar_left()
	if event.is_action_pressed("inventory_up"):
		hotbar_right()
	for i in range(HOTBAR_SIZE):
		if event.is_action_pressed("hotbar_" + str(i + 1)):
			selected_slot = i
			update_hotbar_display()
	if event.is_action_pressed("inventory"):
		toggle_inventory()

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
	if target.block_material.hardness > mining_power:
		return
	mining_progress += delta * get_mining_speed()
	mining_bar.value = mining_progress / mining_target.block_material.mining_time
	mining_bar.visible = true
	
	if mining_progress >= mining_target.block_material.mining_time:
		finish_mining()

func get_mining_speed():
	if equipped_tool != null:
		return equipped_tool.mining_speed
	else:
		return 1

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
	for slot in inventory:
		data.append({"item": slot.item.resource_path, "amount": slot.amount})
	return data

func load_player_save_data(data: Array):
	inventory.clear()
	for entry in data:
		var item = load(entry["item"]) as Item
		var amount = int(entry["amount"])
		inventory.append(InventorySlot.new(item, amount))

func get_hotbar_save_data() -> Array:
	var data = []
	for item in hotbar:
		if item == null:
			data.append(null)
		else:
			data.append(item.resource_path)
	return data

func load_hotbar_save_data(data: Array):
	hotbar.resize(HOTBAR_SIZE)
	hotbar.fill(null)
	for i in range(min(data.size(), HOTBAR_SIZE)):
		if data[i] != null:
			hotbar[i] = load(data[i]) as Item

func save_equipped_item():
	var data
	if equipped_tool == null:
		data = "None"
	else:
		data = equipped_tool.resource_path
	return data

func load_equipped_tool(data):
	if data == "None":
		equipped_tool = null
	else: 
		equipped_tool = load(data) as Item
