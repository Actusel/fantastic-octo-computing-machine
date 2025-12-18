extends BaseEnemy

@onready var shoot_timer: Timer = $ShootTimer
# detection_radius, hp_bar, ray_cast are in BaseEnemy

@export var projectile_scene: PackedScene = preload("res://combat/enemy_projectile.tscn")

# player is in BaseEnemy
# A simple flag to control firing rate
# Using can_attack from BaseEntity instead of can_shoot

func _ready() -> void:
	super._ready()
	shoot_timer.start()
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)

func drop_item():
	var item_scene = preload("res://items&inventory/item.tscn")
	var arrow_data = preload("res://items&inventory/items/arrow.tres")
	var wine_data = preload("res://items&inventory/items/wine.tres")
	
	var item_instance = item_scene.instantiate()
	
	if randf() > 0.5:
		item_instance.item_data = arrow_data
	else:
		item_instance.item_data = wine_data
		
	# Random position within a small radius (e.g., 30 pixels)
	var random_offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	item_instance.global_position = global_position + random_offset
	
	get_parent().call_deferred("add_child", item_instance)

func _on_shoot_timer_timeout() -> void:
	# When the timer finishes, allow the enemy to shoot again
	can_attack = true

func _physics_process(delta: float) -> void:
	# If we don't have a player target, do nothing.
	if player == null:
		return
	
	# --- Line of Sight (LOS) Logic ---
	
	# 1. Point the RayCast at the player
	# We convert the player's global position to the RayCast's local space
	ray_cast.target_position = to_local(player.global_position)
	
	# 2. Force the RayCast to update its collision info immediately
	ray_cast.force_raycast_update()
	
	# 3. Check if the ray is colliding with anything
	# Because we set the RayCast's mask to "world", it will ONLY hit walls.
	if not ray_cast.is_colliding():
		
		shoot()


func shoot():
	if not can_attack or projectile_scene == null:
		return
	
	can_attack = false
	shoot_timer.start()

	print("shoot")

	# Number of projectiles
	var count := 8
	var full_circle := TAU  # Equivalent to 2 * PI
	var angle_step := full_circle / count

	for i in count:
		var projectile := projectile_scene.instantiate()
		get_parent().add_child(projectile)

		# Position the projectile at the enemy's position
		projectile.global_position = global_position

		# Compute direction angle for this projectile
		var angle := i * angle_step
		var direction := Vector2.RIGHT.rotated(angle)

		# Use setup_straight
		projectile.setup_straight(direction, 300.0, 10.0)
