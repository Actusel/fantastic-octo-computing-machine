extends BaseEnemy

# --- Enemy Stats ---
@export var melee_damage: float = 25.0 # This will be overwritten by ItemData
@export var weapon_data: ItemData
# speed, arrival_tolerance are in BaseEnemy/BaseEntity

# --- Node References ---
# detection_radius, ray_cast are in BaseEnemy
@onready var melee_area: Area2D = $MeleeArea
@onready var attack_timer: Timer = $AttackTimer
@onready var sprite: Sprite2D = $Sprite2D # Optional
@onready var weapon_sprite: Sprite2D = $WeaponSprite
# hp_bar is in BaseEntity

	
# --- State Variables ---
# player is in BaseEnemy
var last_known_position: Vector2 = Vector2.ZERO
var is_attacking: bool = false
var show_attack_flash: bool = false


func _ready() -> void:
	super._ready()
	# Initialize last_known_position to its own position
	# This prevents it from running to (0,0) at the start
	last_known_position = global_position
	
	# --- Weapon Setup ---
	if weapon_data and weapon_data.icon and weapon_data.strongness:
		weapon_sprite.texture = weapon_data.icon
		melee_damage = weapon_data.strongness # Set damage from ItemData
	else:
		# Hide weapon if no data is provided
		weapon_sprite.visible = false
		
	# Hide weapon sprite initially
	weapon_sprite.visible = false
	# Connect signals (if not done in the editor)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	

func _physics_process(_delta: float) -> void:
	# Reset velocity every frame
	velocity = Vector2.ZERO
	
	if is_attacking:
		move_and_slide()
		return

	# If no player is targeted, don't do anything
	if player !=null:
		ray_cast.target_position = to_local(player.global_position)
		ray_cast.force_raycast_update()

	# --- Line of Sight (LOS) Logic ---
	
	# 1. Point the RayCast at the player
		
	
	# 2. Check if the ray is colliding with a "world" object
	if not ray_cast.is_colliding() and player != null:
		# --- WE CAN SEE THE PLAYER ---
		
		# Update the last known position
		last_known_position = player.global_position
		
		# Point at the player
		look_at(player.global_position)
		
		# --- Attack or Chase ---
		var is_player_in_range = false
		for body in melee_area.get_overlapping_bodies():
			if body.is_in_group("player"):
				is_player_in_range = true
				break
	
		if is_player_in_range:
			# Player is in melee range, stop moving and try to attack
			try_attack(player)
		else:
			# Player is not in range, move towards them
			var direction = (player.global_position - global_position).normalized()
			velocity = direction * speed
		
	else:
		# --- WE CANNOT SEE THE PLAYER ---
		
		
		# Move towards the last known position, if not already there
		if global_position.distance_to(last_known_position) > arrival_tolerance and last_known_position:
			var direction = (last_known_position - global_position).normalized()
			velocity = direction * speed
			look_at(last_known_position) # Look where it's going

	# Apply the calculated velocity
	move_and_slide()

func try_attack(target: Node2D) -> void:
	if not can_attack or weapon_data == null:
		return # Attack is on cooldown or no weapon equipped

	# Start the attack cooldown
	can_attack = false
	is_attacking = true
	attack_timer.start()
	
	# --- Animation Setup ---
	var tween = create_tween()
	var swing_duration = 0.6     # Total swing animation time
	var damage_delay = 0.4      # When to apply damage relative to start
	var start_angle = deg_to_rad(-30)
	var end_angle = deg_to_rad(30)
	
	# Set initial state
	weapon_sprite.rotation = start_angle
	weapon_sprite.visible = true
	
	# 1. Animate the swing (main track)
	tween.tween_property(weapon_sprite, "rotation", end_angle, swing_duration) \
		 .set_trans(Tween.TRANS_CUBIC) \
		 .set_trans(Tween.TRANS_LINEAR)
	
	# 2. Run the damage callback *in parallel* with a delay
	tween.parallel() \
		 .tween_callback(_apply_damage.bind(target)) \
		 .set_delay(damage_delay)
	
	# 3. Hide weapon when animation completes
	tween.tween_callback(weapon_sprite.hide)
	tween.tween_callback(func(): is_attacking = false)



# This new function holds the damage logic
func _apply_damage(target: Node2D) -> void:
	flash_attack_area()
	# We must check again if the target is still valid and in range
	# This prevents the player from being hit if they dash away just in time
	var is_player_still_in_range = false
	for body in melee_area.get_overlapping_bodies():
		if body == target:
			is_player_still_in_range = true
			break

	if is_player_still_in_range:
		print("Enemy attack HITS!")
		if target.has_method("take_damage"):
			target.take_damage(melee_damage)
		elif target.has_method("hp_changed"):
			target.hp_changed(-melee_damage)
	else:
		print("Enemy attack WHIFFS!")

# --- Signal Handlers ---

# _on_detection_radius_body_entered/exited are in BaseEnemy

func _on_attack_timer_timeout() -> void:
	# When the timer finishes, allow the enemy to attack again
	can_attack = true

func flash_attack_area():
	show_attack_flash = true
	queue_redraw()
	await get_tree().create_timer(0.1).timeout
	show_attack_flash = false
	queue_redraw()

func _draw():
	if show_attack_flash:
		var collision_shape: CollisionShape2D = null
		for child in melee_area.get_children():
			if child is CollisionShape2D:
				collision_shape = child
				break
		
		if collision_shape and collision_shape.shape is RectangleShape2D:
			var rect_size = collision_shape.shape.size
			var rect_pos = melee_area.position + collision_shape.position - rect_size / 2
			draw_rect(Rect2(rect_pos, rect_size), Color(1, 0, 0, 0.5), true)
