extends Subworld

@export var dirt: BlockMaterial
@export var stone: BlockMaterial
@export var air: BlockMaterial
@export var coal: BlockMaterial
@export var ores: Array[OreDefinition] = []
@export var layers: Array[WorldLayer] = []
var layer_starts: Array[int] = []
var ore_noises: Dictionary = {}
const CHUNK_SIZE = 16
const BLOCK_SIZE = 64
var loaded_chunks: Dictionary = {}
var block_scene = preload("res://blocks/block.tscn")
const RENDER_DISTANCE := 2
var current_player_chunk: Vector2i
var world_seed: int = 12345
var coal_noise = FastNoiseLite.new()

func initialize_world():
	initialize_layers()
	initialize_ores()
	initialize_chunks()
	initialized = true

func initialize_chunks():
	current_player_chunk = get_player_chunk()
	update_chunks()

func initialize_layers():
	layer_starts.clear()
	var depth := 0
	for layer in layers:
		layer_starts.append(depth)
		depth += layer.thickness

func initialize_ores():
	ore_noises.clear()
	for layer in layers:
		for ore in layer.ores:
			var noise = FastNoiseLite.new()
			noise.seed = world_seed + ore.seed_offset
			noise.frequency = ore.frequency
			ore_noises[ore] = noise

func _process(_delta):
	if not initialized:
		return
	var new_player_chunk = get_player_chunk()
	if new_player_chunk != current_player_chunk:
		current_player_chunk = new_player_chunk
		update_chunks()

func spawn_block(location: Vector2i, block_material: BlockMaterial, chunk: Node2D):
	if block_material == air:
		return
	var block = block_scene.instantiate()
	block.world_position = location
	block.position = Vector2i(location.x * BLOCK_SIZE, location.y * BLOCK_SIZE)
	block.set_block_material(block_material)
	chunk.add_child(block)

func get_ore_at(location: Vector2i, layer: WorldLayer, layer_start: int) -> BlockMaterial:
	var local_y = location.y - layer_start
	for ore in layer.ores:
		if local_y > ore.max_depth:
			continue
		if local_y < ore.min_depth:
			continue
		var noise = ore_noises[ore]
		var noise_value = noise.get_noise_2d(location.x, location.y)
		if noise_value > ore.threshold:
			return ore.ore_material
	return null

func get_natural_material_at(location: Vector2i) -> BlockMaterial:
	if location.y < 0:
		return air
	var layer := get_layer_at_depth(location.y)
	var layer_index := get_layer_index_at_depth(location.y)
	if layer == null:
		return air
	var layer_start := layer_starts[layer_index]
	var ore = get_ore_at(location, layer, layer_start)
	if ore != null:
		return ore
	return layer.base_material

func generate_chunk(chunk_x: int, chunk_y: int):
	var chunk_position = Vector2i(chunk_x, chunk_y)
	if loaded_chunks.has(chunk_position):
		return
	var chunk = Node2D.new()
	chunk.name = "Chunk_%d_%d" % [chunk_x, chunk_y]
	add_child(chunk)
	loaded_chunks[chunk_position] = chunk
	for local_x in range(CHUNK_SIZE):
		for local_y in range(CHUNK_SIZE):
			var world_x = chunk_x * CHUNK_SIZE + local_x
			var world_y = chunk_y * CHUNK_SIZE + local_y
			var block_position = Vector2i(world_x, world_y)
			var block_material = get_material_at(block_position)
			var location = Vector2(world_x, world_y)
			spawn_block(location, block_material, chunk)

func get_player_chunk() -> Vector2i:
	var block_x = floori(player.global_position.x / BLOCK_SIZE)
	var block_y = floori(player.global_position.y / BLOCK_SIZE)
	var chunk_x = floori(float(block_x) / CHUNK_SIZE)
	var chunk_y = floori(float(block_y) / CHUNK_SIZE)
	return Vector2i(chunk_x, chunk_y)

func update_chunks():
	var player_chunk = get_player_chunk()
	for x in range(player_chunk.x - RENDER_DISTANCE, player_chunk.x + RENDER_DISTANCE + 1):
		for y in range(player_chunk.y - RENDER_DISTANCE, player_chunk.y + RENDER_DISTANCE + 1):
			generate_chunk(x, y)
	unload_distant_chunks()

func get_material_at(location: Vector2i) -> BlockMaterial:
	if block_overrides.has(location):
		return block_overrides[location]
	return get_natural_material_at(location)

func mark_block_mined(location: Vector2i):
	var natural_block = get_natural_material_at(location)
	if natural_block == air:
		block_overrides.erase(location)
	else: block_overrides[location] = air

func place_block(location: Vector2i, block: BlockMaterial):
	var natural_block = get_natural_material_at(location)
	if natural_block == block:
		block_overrides.erase(location)
	else: block_overrides[location] = block
	var chunk_position = Vector2i(floori(float(location.x) / CHUNK_SIZE), floori(float(location.y) / CHUNK_SIZE))
	if loaded_chunks.has(chunk_position):
		var chunk = loaded_chunks[chunk_position]
		spawn_block(location, block, chunk)

func unload_distant_chunks():
	var chunks_to_unload = []
	for chunk_position in loaded_chunks:
		var x_distance = abs(chunk_position.x - current_player_chunk.x)
		var y_distance = abs(chunk_position.y - current_player_chunk.y)
		if x_distance > RENDER_DISTANCE or y_distance > RENDER_DISTANCE:
			chunks_to_unload.append(chunk_position)
	for chunk_position in chunks_to_unload:
		loaded_chunks[chunk_position].queue_free()
		loaded_chunks.erase(chunk_position)



func get_layer_index_at_depth(y: int) -> int:
	var low := 0
	var high := layer_starts.size() - 1
	while low <= high:
		@warning_ignore("integer_division")
		var mid := (high + low) / 2
		var start := layer_starts[mid]
		var end := start + layers[mid].thickness
		if y < start:
			high = mid - 1
		elif y >= end:
			low = mid+1
		else: 
			return mid
	return -1

func get_layer_at_depth(y: int) -> WorldLayer:
	var index = get_layer_index_at_depth(y)
	if index == -1:
		return null
	return layers[index]

func get_runtime_state() -> Dictionary:
	return {"block_overrides": get_save_data(),"seed": world_seed}

func load_runtime_state(state: Dictionary):
	load_save_data(state.get("block_overrides", []))
	world_seed = state.get("seed", 12345)
