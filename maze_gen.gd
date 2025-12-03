extends Node2D

# --- Configuration ---
@export_category("Maze Settings")
@onready var tile_map_layer: TileMapLayer = $"../TileMapLayer"
@export var maze_size: Vector2i = Vector2i(10, 10):
	set(value):
		maze_size = value
		# Prevent negative or zero sizes
		if maze_size.x < 1: maze_size.x = 1
		if maze_size.y < 1: maze_size.y = 1

@export var corridor_width: int = 5
@export var wall_thickness: int = 1

@export_category("Tile Configuration")
@export var source_id: int = 8
@export var wall_atlas_coords: Vector2i = Vector2i(20, 10)
@export var floor_atlas_coords: Vector2i = Vector2i(1, 5)
@export var start_atlas_coords: Vector2i = Vector2i(10, 9)
@export var end_atlas_coords: Vector2i = Vector2i(14, 8)

# --- State ---
var _visited: Dictionary = {}
var _stack: Array[Vector2i] = []

func _ready() -> void:
	if not tile_map_layer:
		push_error("MazeGenerator: Please assign a TileMapLayer in the inspector.")
		return
	
	# Optional: Generate immediately on run
	generate_maze()

func generate_maze() -> void:
	if not tile_map_layer: 
		return

	print("Generating Maze...")
	tile_map_layer.clear()
	_visited.clear()
	_stack.clear()
	
	# 1. Fill the entire area with walls first
	# Calculate total physical size including walls
	# Formula: (Cells * (Width + Wall)) + Outer Wall Border
	var stride = corridor_width + wall_thickness
	var total_width = (maze_size.x * stride) + wall_thickness
	var total_height = (maze_size.y * stride) + wall_thickness
	
	for x in range(total_width):
		for y in range(total_height):
			set_tile(x, y, true) # true = wall
			
	# 2. Start Recursive Backtracker
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
			
	_place_start_and_end()
	print("Maze Generation Complete.")

# --- Logic Helpers ---

func _place_start_and_end() -> void:
	# Define the 4 logical corners
	var corners = [
		Vector2i(0, 0),
		Vector2i(maze_size.x - 1, 0),
		Vector2i(0, maze_size.y - 1),
		Vector2i(maze_size.x - 1, maze_size.y - 1)
	]
	
	# Filter distinct corners (handles 1x1 or 1xN maze edge cases)
	var distinct_corners = []
	for c in corners:
		if not c in distinct_corners:
			distinct_corners.append(c)
	
	distinct_corners.shuffle()
	
	if distinct_corners.size() > 0:
		var start_pos = distinct_corners[0]
		_paint_special_room(start_pos, start_atlas_coords)
		
		# Pick a different corner for end if possible
		if distinct_corners.size() > 1:
			var end_pos = distinct_corners[1]
			_paint_special_room(end_pos, end_atlas_coords)
		else:
			# Fallback for 1x1 maze: start and end are same
			_paint_special_room(start_pos, end_atlas_coords)

func _paint_special_room(logical_pos: Vector2i, atlas_coords: Vector2i) -> void:
	var stride = corridor_width + wall_thickness
	
	# Calculate top-left pixel of this 'room'
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
		# Check bounds
		if check.x >= 0 and check.x < maze_size.x and check.y >= 0 and check.y < maze_size.y:
			if not _visited.has(check):
				list.append(check)
	return list

# This function converts the logical grid coordinate (e.g., 0,0) 
# into the physical TileMap coordinates and carves a 5x5 floor area
func _carve_room(logical_pos: Vector2i) -> void:
	var stride = corridor_width + wall_thickness
	
	# Calculate top-left pixel of this 'room', adding wall_thickness for the outer border
	var start_x = (logical_pos.x * stride) + wall_thickness
	var start_y = (logical_pos.y * stride) + wall_thickness
	
	for x in range(corridor_width):
		for y in range(corridor_width):
			set_tile(start_x + x, start_y + y, false) # false = floor

# Removes the tiles between two logical cells to create a path
func _remove_wall_between(current: Vector2i, next: Vector2i) -> void:
	var diff = next - current
	var stride = corridor_width + wall_thickness
	
	# Base coordinates of current room
	var start_x = (current.x * stride) + wall_thickness
	var start_y = (current.y * stride) + wall_thickness
	
	# If moving RIGHT
	if diff == Vector2i.RIGHT:
		# Carve wall to the right of current room
		var wall_x = start_x + corridor_width
		for i in range(wall_thickness):
			for y in range(corridor_width):
				set_tile(wall_x + i, start_y + y, false)
				
	# If moving LEFT
	elif diff == Vector2i.LEFT:
		# Carve wall to the left of current room (which is actually inside the prev block space)
		var wall_x = start_x - wall_thickness
		for i in range(wall_thickness):
			for y in range(corridor_width):
				set_tile(wall_x + i, start_y + y, false)
				
	# If moving DOWN
	elif diff == Vector2i.DOWN:
		var wall_y = start_y + corridor_width
		for i in range(wall_thickness):
			for x in range(corridor_width):
				set_tile(start_x + x, wall_y + i, false)

	# If moving UP
	elif diff == Vector2i.UP:
		var wall_y = start_y - wall_thickness
		for i in range(wall_thickness):
			for x in range(corridor_width):
				set_tile(start_x + x, wall_y + i, false)

# Helper to actually place the tile on the layer
func set_tile(x: int, y: int, is_wall: bool) -> void:
	var coords = wall_atlas_coords if is_wall else floor_atlas_coords
	tile_map_layer.set_cell(Vector2i(x, y), source_id, coords)
