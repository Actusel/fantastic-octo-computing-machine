extends CharacterBody2D

@onready var detection_radius: Area2D = $DetectionRadius
@onready var hp_bar: ProgressBar = $hp_bar
@onready var shoot_timer: Timer = $ShootTimer
@onready var ray_cast: RayCast2D = $RayCast2D

@export var projectile_scene: PackedScene = preload("res://combat/enemy_projectile.tscn")

var player: CharacterBody2D = null 
# A simple flag to control firing rate
var can_shoot: bool = false



func _ready() -> void:
	detection_radius.body_entered.connect(_on_detection_radius_body_entered)
	detection_radius.body_exited.connect(_on_detection_radius_body_exited)
	shoot_timer.start()
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)


func hp_changed(amount):
	hp_bar.value+=amount
	if hp_bar.value==0:
		queue_free()

func _on_detection_radius_body_entered(body: Node2D):
	# Check if the body that entered is in the "player" group
	if body.is_in_group("player"):
		player = body as CharacterBody2D # Store the player reference
	
func _on_detection_radius_body_exited(body: Node2D):
	if body == player:
		player = null
		
func _on_shoot_timer_timeout() -> void:
	# When the timer finishes, allow the enemy to shoot again
	can_shoot = true

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
	if not can_shoot or projectile_scene == null:
		return
	
	can_shoot = false
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

		# Assign the direction to the projectile if it expects a velocity/direction variable
		
		projectile.direction = direction
		
		# Optional: rotate projectile visually to match its travel direction
		projectile.rotation = angle
