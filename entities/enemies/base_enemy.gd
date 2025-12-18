class_name BaseEnemy extends BaseEntity

@export var arrival_tolerance: float = 3.0
@export var loot_table: Array[ItemData] = [] # Or use PackedScenes/Resources

# Common references
var player: CharacterBody2D = null
var detection_radius: Area2D
var ray_cast: RayCast2D

func _ready() -> void:
	super._ready()
	
	# Try to find common nodes
	if has_node("DetectionRadius"):
		detection_radius = $DetectionRadius
		detection_radius.body_entered.connect(_on_detection_radius_body_entered)
		detection_radius.body_exited.connect(_on_detection_radius_body_exited)
		
	if has_node("RayCast2D"):
		ray_cast = $RayCast2D

func _on_detection_radius_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body as CharacterBody2D

func _on_detection_radius_body_exited(body: Node2D) -> void:
	if body == player:
		player = null

func die():
	drop_item()
	queue_free()

func drop_item():
	# Default implementation using the hardcoded logic from melee_enemy for now
	# Ideally this uses loot_table
	var item_scene = preload("res://items&inventory/item.tscn")
	var spear_data = preload("res://items&inventory/items/spear.tres")
	var wine_data = preload("res://items&inventory/items/wine.tres")
	var item_instance = item_scene.instantiate()
	
	if randf() > 0.5:
		item_instance.item_data = spear_data
	else:
		item_instance.item_data = wine_data
		
	var random_offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	item_instance.global_position = global_position + random_offset
	
	get_parent().call_deferred("add_child", item_instance)
