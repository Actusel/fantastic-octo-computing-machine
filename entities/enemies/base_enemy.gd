class_name BaseEnemy extends BaseEntity

@export var arrival_tolerance: float = 3.0
@export var loot_table: Array[LootItem] = [preload("res://wine_enemy_drops.tres")]

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
	var item_scene = preload("res://items&inventory/item.tscn")
	
	for loot_entry in loot_table:
		if not loot_entry or not loot_entry.item_data:
			continue
			
		if loot_entry.chance >= 1.0 or randf() <= loot_entry.chance:
			var count = loot_entry.get_drop_count()
			if count > 0:
				var item_instance = item_scene.instantiate()
				item_instance.item_data = loot_entry.item_data
				item_instance.amount = count
				
				var random_offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
				item_instance.global_position = global_position + random_offset
				
				get_parent().call_deferred("add_child", item_instance)
