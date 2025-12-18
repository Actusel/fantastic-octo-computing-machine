extends BaseEntity
class_name Player

@onready var dash_cooldown = $dash_cooldown
@onready var dash_icon = $ColorRect
@onready var label = $ui/Label
@onready var inventory: Control = $ui/inventory
# hp_bar is handled in BaseEntity
@onready var hp_label: Label = $ui/hp_label
@onready var weapon_sprite: Sprite2D = $WeaponTexture
@onready var attack_timer: Timer = $AttackTimer
@onready var melee_area: Area2D = $MeleeArea
@onready var player_sprite: Sprite2D = $PlayerSprite
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var projectile_spawn: Marker2D = $ProjectileSpawn
# Decoupled MazeGen reference
signal player_died

var save_label: Label

@export var weapon: ItemData = null
# can_attack is in BaseEntity
var enemy: CharacterBody2D = null

# SPEED is in BaseEntity as speed
const dash_time = 0.2
const DASH_SPEED = 600
const push_str = 100
var dashing = false
var dash_timer: float
var damage: float

func _ready() -> void:
	super._ready()
	# Create Save Label
	save_label = Label.new()
	save_label.text = "Progress Saved"
	save_label.visible = false
	save_label.position = Vector2(20, 20) # Adjust position as needed
	save_label.add_theme_color_override("font_color", Color.YELLOW)
	$ui.add_child(save_label)
	
	SaveManager.game_saved.connect(_on_game_saved)

	hp_label.text = str(hp_bar.value) + "/" + str(hp_bar.max_value)
	
	melee_area.body_entered.connect(_on_melee_area_area_entered)
	melee_area.body_exited.connect(_on_melee_area_area_exited)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	# Sync with Global equipment
	Global.reapply_equipment_effects()

func _on_game_saved():
	if save_label:
		save_label.visible = true
		var timer = get_tree().create_timer(2.0)
		timer.timeout.connect(func(): save_label.visible = false)
	
func hp_changed(amount):
	if amount < 0:
		if not dashing:
			take_damage(-amount)
	else:
		heal(amount)
	
	hp_label.text = str(current_hp) + "/" + str(max_hp)

func die():
	emit_signal("player_died")
	current_hp = max_hp
	update_health_ui()
	hp_label.text = str(current_hp) + "/" + str(max_hp)

func max_hp_changed(amount):
	max_hp += amount
	current_hp += amount
	update_health_ui()
	hp_label.text = str(current_hp) + "/" + str(max_hp)

func change_weapon(new_weapon: ItemData ):
	if new_weapon == null:
		return
		
	weapon=new_weapon
	weapon_sprite.texture = weapon.icon
	damage = weapon.strongness
	if weapon.weapon_range == "long": weapon_sprite.visible = true
	else: weapon_sprite.visible = false
	
func clear_weapon():
	weapon = null
	weapon_sprite.texture = null
	weapon_sprite.visible = false

func dash_indicator():
	if dash_cooldown.time_left: return snapped(dash_cooldown.time_left,.01) 
	else: return "ready" 

func _physics_process(delta):
	hp_label.text = str(hp_bar.value) + "/" + str(hp_bar.max_value)
	look_at(get_global_mouse_position())
	collision_shape_2d.rotation = -rotation
	player_sprite.rotation = -rotation
	var direction = Input.get_vector("moveleft","moveright","moveup","movedown")
	label.set_text(str(dash_indicator()))
	
	if Input.is_action_pressed("attack") and weapon: # This is a temporary solution to get both enemy and player attacks up and working.
		if weapon.weapon_range == "long": 
			shoot()
		else:
			try_attack(enemy)
	
	if dashing:
		dash_timer-=delta
		if dash_timer>=0: 
			dashing=false
	elif Input.is_action_just_pressed("dash") and !dash_cooldown.time_left and direction!=Vector2.ZERO:
		dashing=true
		dash_cooldown.start()
		dash_timer=dash_time
		velocity=direction*DASH_SPEED
	else: 
		velocity.x = move_toward(velocity.x, direction.x*speed, 40)
		velocity.y = move_toward(velocity.y, direction.y*speed, 40)
	
	move_and_slide()
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		if body.is_in_group("movable"):
			body.apply_central_impulse(-collision.get_normal()*push_str)
			
			
			
func shoot() -> void:
	# Only shoot if the timer is ready and we have a projectile scene
	if not can_attack or weapon.projectile_scene == null:
		return
		
	# Check for arrows in offhand via Global
	var offhand_slot = Global.equipment["offhand"]
	if offhand_slot == null or offhand_slot["item"].type != "arrow":
		return

	# Consume arrow
	if not Global.consume_equipment("offhand", 1):
		return

	# Stop shooting and start the cooldown timer
	can_attack = false
	attack_timer.wait_time=0.5+randf()
	attack_timer.start()

	# --- Instance and configure the projectile ---
	var projectile = weapon.projectile_scene.instantiate() as Area2D
	
	# Use the new setup function
	projectile.global_position = projectile_spawn.global_position
	projectile.setup_straight(global_transform.x.normalized(), 600.0, damage)
	
	# Add the projectile to the main scene tree
	get_tree().root.add_child(projectile)

func try_attack(target: Node2D) -> void:
	if not can_attack or weapon == null:
		return # Attack is on cooldown or no weapon equipped

	# Start the attack cooldown
	can_attack = false
	attack_timer.start()
	
	# --- Animation Setup ---
	var tween = create_tween()
	var swing_duration = 0.2     # Total swing animation time
	var damage_delay = 0.1      # When to apply damage relative to start
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



# This new function holds the damage logic
func _apply_damage(target: Node2D) -> void:
	# We must check again if the target is still valid and in range
	# This prevents the player from being hit if they dash away just in time
	print(target)
	print(enemy)
	var is_enemy_still_in_range = false
	for body in melee_area.get_overlapping_bodies():
		if body == target:
			is_enemy_still_in_range = true
			break

	if is_enemy_still_in_range:
		print("Player attack HITS!")
		if target.has_method("take_damage"):
			target.take_damage(damage)
		elif target.has_method("hp_changed"):
			target.hp_changed(-damage)
	else:
		print("Player attack WHIFFS!")


func _on_melee_area_area_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		enemy = body as CharacterBody2D


func _on_melee_area_area_exited(body: Node2D) -> void:
	if body == enemy:
		enemy = null


func _on_attack_timer_timeout() -> void:
	can_attack = true
