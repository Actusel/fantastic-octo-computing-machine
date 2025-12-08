extends Node2D

# --- Configuration ---
@export_category("Maze Settings")
@onready var tile_map_layer: TileMapLayer = $"../TileMapLayer"
@onready var player: Player = $"../player"
@export var maze_size: Vector2i = Vector2i(5, 5): # Starting size
	set(value):
		maze_size = value
		if maze_size.x < 2: maze_size.x = 2
		if maze_size.y < 2: maze_size.y = 2
@export var corridor_width: int = 10
@export var wall_thickness: int = 3

@export_category("Tile Configuration")
@export var source_id: int = 8
@export var wall_atlas_coords: Vector2i = Vector2i(17, 3)
@export var floor_atlas_coords: Vector2i = Vector2i(1, 5)
@export var start_atlas_coords: Vector2i = Vector2i(10, 9)
@export var end_atlas_coords: Vector2i = Vector2i(14, 8)


@export_category("Enemies")
@export var turret_enemy_scene: PackedScene
@export var melee_enemy_scene: PackedScene
@export var spike_shooter_enemy_scene: PackedScene
@export_range(0.0, 1.0) var spawn_chance: float = 0.1

# --- State ---
var level = maze_size.x
var _visited: Dictionary = {}
var _stack: Array[Vector2i] = []
var _goal_area: Area2D = null
var _enemies_container: Node2D = null
var _start_pos: Vector2i = Vector2i(-1, -1)
var _end_pos: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	if not tile_map_layer or not player:
		push_error("MazeGenerator: Please assign TileMapLayer AND Player in inspector.")
		return
	Global.level = level
	# Create a container for enemies to make cleanup easier
	_enemies_container = Node2D.new()
	_enemies_container.name = "EnemiesContainer"
	add_child(_enemies_container)
	
	# Generate the first level
	generate_maze()

func generate_maze() -> void:
	print("Generating Level: ", maze_size)
	
	# Cleanup previous level artifacts
	tile_map_layer.clear()
	_visited.clear()
	_stack.clear()
	
	if _goal_area:
		_goal_area.queue_free()
		_goal_area = null
		
	# Clear old enemies
	for child in _enemies_container.get_children():
		child.queue_free()
	
	# 1. Fill area with walls
	var stride = corridor_width + wall_thickness
	var total_width = (maze_size.x * stride) + wall_thickness
	var total_height = (maze_size.y * stride) + wall_thickness
	
	for x in range(total_width):
		for y in range(total_height):
			set_tile(x, y, true) # true = wall
			
	# 2. Recursive Backtracker
	var start_pos = Vector2i(0, 0)
	_push_cell(start_pos)
	
	while _stack.size() > 0:
		var current = _stack.back()
		var neighbors = _get_unvisited_neighbors(current)
		
		if neighbors.size() > 0:
			var next = neighbors.pick_random()
			_remove_wall_between(current, next)
			_push_cell(next)
		else:
			_stack.pop_back()
			
	# 3. Setup Gameplay elements (Start/End)
	_setup_level_markers()
	
	# 4. Spawn Enemies
	_spawn_enemies()

# --- Gameplay Logic ---

func _setup_level_markers() -> void:
	var corners = [
		Vector2i(0, 0),
		Vector2i(maze_size.x - 1, 0),
		Vector2i(0, maze_size.y - 1),
		Vector2i(maze_size.x - 1, maze_size.y - 1)
	]
	
	# Get unique corners
	var distinct_corners = []
	for c in corners:
		if not c in distinct_corners:
			distinct_corners.append(c)
	
	distinct_corners.shuffle()
	
	# Reset state positions
	_start_pos = Vector2i(-1, -1)
	_end_pos = Vector2i(-1, -1)
	
	if distinct_corners.size() > 0:
		_start_pos = distinct_corners[0]
		_paint_special_room(_start_pos, start_atlas_coords)
		_move_player_to_cell(_start_pos)
		
		if distinct_corners.size() > 1:
			_end_pos = distinct_corners[1]
			_paint_special_room(_end_pos, end_atlas_coords)
			_create_goal_trigger(_end_pos)

func _spawn_enemies() -> void:
	# Gather valid enemy scenes
	var available_enemies = []
	if turret_enemy_scene: available_enemies.append(turret_enemy_scene)
	if melee_enemy_scene: available_enemies.append(melee_enemy_scene)
	if spike_shooter_enemy_scene: available_enemies.append(spike_shooter_enemy_scene)
	
	if available_enemies.is_empty():
		return

	# Iterate through all visited rooms (logical coordinates)
	for room_pos in _visited.keys():
		# Do not spawn on start or end tiles
		if room_pos == _start_pos or room_pos == _end_pos:
			continue
			
		# 10% Chance (configurable via spawn_chance)
		if randf() < spawn_chance:
			var enemy_scene = available_enemies.pick_random()
			var enemy_instance = enemy_scene.instantiate()
			_enemies_container.add_child(enemy_instance)
			
			# Position enemy in center of the room
			var center_tile = _get_center_tile_of_room(room_pos)
			enemy_instance.global_position = tile_map_layer.map_to_local(center_tile)

func _move_player_to_cell(logical_pos: Vector2i) -> void:
	var center_tile = _get_center_tile_of_room(logical_pos)
	# map_to_local returns pixel center of the tile
	player.global_position = tile_map_layer.map_to_local(center_tile)
	# Reset player velocity if needed
	player.velocity = Vector2.ZERO

func _create_goal_trigger(logical_pos: Vector2i) -> void:
	var center_tile = _get_center_tile_of_room(logical_pos)
	var world_pos = tile_map_layer.map_to_local(center_tile)
	
	# Create Area2D programmatically
	_goal_area = Area2D.new()
	_goal_area.name = "GoalArea"
	_goal_area.collision_mask = 2
	add_child(_goal_area)
	_goal_area.global_position = world_pos
	
	# Create Collision Shape
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	
	# Size the trigger to be roughly the size of the 5x5 room
	var tile_size = tile_map_layer.tile_set.tile_size
	rect.size = Vector2(corridor_width * tile_size.x, corridor_width * tile_size.y)
	shape.shape = rect
	_goal_area.add_child(shape)
	
	# Connect signal
	_goal_area.body_entered.connect(_on_goal_reached)

func _on_goal_reached(body: Node2D) -> void:
	if body == player:
		call_deferred("_level_up")

func _level_up() -> void:
	print("Level Complete! Increasing size...")
	maze_size += Vector2i(1, 1)
	generate_maze()

# --- Helper Math ---

func _get_center_tile_of_room(logical_pos: Vector2i) -> Vector2i:
	var stride = corridor_width + wall_thickness
	var start_x = (logical_pos.x * stride) + wall_thickness
	var start_y = (logical_pos.y * stride) + wall_thickness
	
	# Calculate the middle tile of the 5x5 block
	var offset = floor(corridor_width / 2.0)
	return Vector2i(start_x + offset, start_y + offset)

# --- Original Generation Logic ---

func _paint_special_room(logical_pos: Vector2i, atlas_coords: Vector2i) -> void:
	var stride = corridor_width + wall_thickness
	var start_x = (logical_pos.x * stride) + wall_thickness
	var start_y = (logical_pos.y * stride) + wall_thickness
	
	for x in range(corridor_width):
		for y in range(corridor_width):
			tile_map_layer.set_cell(Vector2i(start_x + x, start_y + y), source_id, atlas_coords)

func _push_cell(logical_pos: Vector2i) -> void:
	_visited[logical_pos] = true
	_stack.append(logical_pos)
	_carve_room(logical_pos)

func _get_unvisited_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for dir in directions:
		var check = pos + dir
		if check.x >= 0 and check.x < maze_size.x and check.y >= 0 and check.y < maze_size.y:
			if not _visited.has(check):
				list.append(check)
	return list

func _carve_room(logical_pos: Vector2i) -> void:
	var stride = corridor_width + wall_thickness
	var start_x = (logical_pos.x * stride) + wall_thickness
	var start_y = (logical_pos.y * stride) + wall_thickness
	
	for x in range(corridor_width):
		for y in range(corridor_width):
			set_tile(start_x + x, start_y + y, false) 

func _remove_wall_between(current: Vector2i, next: Vector2i) -> void:
	var diff = next - current
	var stride = corridor_width + wall_thickness
	var start_x = (current.x * stride) + wall_thickness
	var start_y = (current.y * stride) + wall_thickness
	
	if diff == Vector2i.RIGHT:
		var wall_x = start_x + corridor_width
		for i in range(wall_thickness):
			for y in range(corridor_width):
				set_tile(wall_x + i, start_y + y, false)
	elif diff == Vector2i.LEFT:
		var wall_x = start_x - wall_thickness
		for i in range(wall_thickness):
			for y in range(corridor_width):
				set_tile(wall_x + i, start_y + y, false)
	elif diff == Vector2i.DOWN:
		var wall_y = start_y + corridor_width
		for i in range(wall_thickness):
			for x in range(corridor_width):
				set_tile(start_x + x, wall_y + i, false)
	elif diff == Vector2i.UP:
		var wall_y = start_y - wall_thickness
		for i in range(wall_thickness):
			for x in range(corridor_width):
				set_tile(start_x + x, wall_y + i, false)

func set_tile(x: int, y: int, is_wall: bool) -> void:
	var coords = wall_atlas_coords if is_wall else floor_atlas_coords
	tile_map_layer.set_cell(Vector2i(x, y), source_id, coords)
