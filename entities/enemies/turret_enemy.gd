extends BaseEnemy
class_name TurretEnemy
# Export the projectile scene so we can assign it in the Inspector
@export var projectile_scene: PackedScene = preload("res://combat/enemy_projectile.tscn")

# --- Node References ---
# detection_radius, ray_cast, hp_bar are in BaseEnemy
@onready var shoot_timer: Timer = $ShootTimer
@onready var projectile_spawn: Marker2D = $ProjectileSpawn
@onready var sprite: Sprite2D = $Sprite2D # Optional, for flipping
@onready var backing_up_range: Area2D = $BackingUpRange
	
# --- State Variables ---
# player is in BaseEnemy
# can_shoot -> can_attack
var run:bool = false
var can_shoot:bool

func _ready() -> void:
	super._ready()
	# Connect signals from code (alternative to using the Node tab)
	backing_up_range.body_entered.connect(_on_backing_up_range_area_entered)
	backing_up_range.body_exited.connect(_on_backing_up_range_area_exited)
	shoot_timer.start()
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	pass

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

func _physics_process(_delta: float) -> void:
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
		# NOT colliding with a wall, so we have a clear line of sight!
		
		# Optional: Make the enemy look at the player
		# You can use this if your sprite is side-on.
		look_at(player.global_position)
		
		# Optional: Flip sprite based on which side the player is on
		# This is for a side-view sprite. For a top-down sprite, 
		# just rotating with look_at() is usually enough.
		# sprite.flip_h = player.global_position.x < global_position.x

		# Try to shoot
		shoot()
		
		if run:
			velocity = Vector2(1, 0).rotated(rotation)*-speed
			move_and_slide()
		else: velocity = Vector2.ZERO
	# If the ray *is* colliding, it means a wall is in the way.
	# The code will do nothing, and the enemy won't shoot.


func shoot() -> void:
	# Only shoot if the timer is ready and we have a projectile scene
	if not can_shoot or projectile_scene == null:
		return

	# Stop shooting and start the cooldown timer
	can_shoot = false
	shoot_timer.wait_time=0.5+randf()
	shoot_timer.start()

	# --- Instance and configure the projectile ---
	var projectile = projectile_scene.instantiate() as Area2D
	
	# Calculate direction from the spawn point (not the enemy center)
	var direction = (player.global_position - projectile_spawn.global_position).normalized()
	
	projectile.global_position = projectile_spawn.global_position
	projectile.setup_straight(direction, 300.0, 10.0)
	
	# Add the projectile to the main scene tree
	get_tree().root.add_child(projectile)


# --- Signal Handlers ---

func _on_detection_radius_body_entered(body: Node2D) -> void:
	# Check if the body that entered is in the "player" group
	if body.is_in_group("player"):
		player = body as CharacterBody2D # Store the player reference


func _on_detection_radius_body_exited(body: Node2D) -> void:
	# If the player is the one who left, clear the reference
	if body == player:
		player = null


func _on_shoot_timer_timeout() -> void:
	# When the timer finishes, allow the enemy to shoot again
	can_shoot = true

func _on_backing_up_range_area_entered(body: Node2D) -> void:
	if body == player:
		run=true



func _on_backing_up_range_area_exited(body) -> void:
	if body == player:
		run=false
