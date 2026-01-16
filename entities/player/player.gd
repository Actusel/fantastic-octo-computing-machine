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
@onready var save_label: Label = $ui/SaveLabel

# Decoupled MazeGen reference
signal player_died


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
var boss_bar: ProgressBar
var current_target: Node2D = null
var aim_indicator: Polygon2D = null

func _ready() -> void:
	super._ready()
	# Apply Exercise Stats (Base Stats)
	max_hp = 100.0 + (Global.stamina * 10.0) # Cardio Bonus
	current_hp = max_hp
	speed = 100.0 + (Global.stamina * 2.0)   # Cardio Speed Bonus
	damage = Global.arm                      # Upper Body Base Damage
	update_health_ui()
	
	# Create Save Label
	
	_setup_boss_bar()
	_setup_aim_indicator()
	
	SaveManager.game_saved.connect(_on_game_saved)

	hp_label.text = str(hp_bar.value) + "/" + str(hp_bar.max_value)
	
	melee_area.body_entered.connect(_on_melee_area_area_entered)
	melee_area.body_exited.connect(_on_melee_area_area_exited)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	# Sync with Global equipment
	Global.reapply_equipment_effects()

func _setup_boss_bar():
	boss_bar = ProgressBar.new()
	$ui.add_child(boss_bar)
	boss_bar.name = "BossHP"
	boss_bar.visible = false
	boss_bar.show_percentage = false
	
	# Set anchors to bottom wide
	boss_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	boss_bar.offset_left = 200
	boss_bar.offset_right = -200
	boss_bar.offset_bottom = -50
	boss_bar.offset_top = -80
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(0.8, 0.1, 0.1) # Red
	boss_bar.add_theme_stylebox_override("fill", style_fill)
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8) # Dark Gray
	boss_bar.add_theme_stylebox_override("background", style_bg)

func update_boss_health(boss_current_hp: float, boss_max_hp: float):
	if not boss_bar.visible:
		boss_bar.visible = true
	boss_bar.max_value = boss_max_hp
	boss_bar.value = boss_current_hp

func hide_boss_health():
	if boss_bar:
		boss_bar.visible = false

func _on_game_saved():
	if save_label:
		save_label.visible = true
		var timer = get_tree().create_timer(2.0)
		timer.timeout.connect(func(): save_label.visible = false)
	
	
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
	damage = weapon.strongness + Global.arm # Add Strength Bonus
	if weapon.weapon_range == "long": weapon_sprite.visible = true
	else: weapon_sprite.visible = false
	
func clear_weapon():
	weapon = null
	weapon_sprite.texture = null
	weapon_sprite.visible = false
	damage = Global.arm # Revert to Unarmed Strength

func dash_indicator():
	if dash_cooldown.time_left: return snapped(dash_cooldown.time_left,.01) 
	else: return "ready" 

func _setup_aim_indicator():
	aim_indicator = Polygon2D.new()
	aim_indicator.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(8, -12), Vector2(-8, -12)
	])
	aim_indicator.color = Color(1, 0, 0, 0.8)
	add_child(aim_indicator)
	aim_indicator.top_level = true
	aim_indicator.visible = false

func find_best_target() -> Node2D:
	if not Global.aim_assist: return null
	
	var enemies = get_tree().get_nodes_in_group("enemy")
	var mouse_pos = get_global_mouse_position()
	var best = null
	var min_dist = INF
	
	var vp_rect = get_viewport_rect()
	var canvas = get_canvas_transform()
	var space = get_world_2d().direct_space_state
	
	for e in enemies:
		if not is_instance_valid(e): continue
		if not e is Node2D: continue
		
		# 1. Onscreen
		var screen_pos = canvas * e.global_position
		if not vp_rect.has_point(screen_pos): continue
		
		# 2. Line of Sight
		var query = PhysicsRayQueryParameters2D.create(projectile_spawn.global_position, e.global_position)
		query.exclude = [self]
		var result = space.intersect_ray(query)
		if result:
			if result.collider != e and not result.collider.is_in_group("enemy"):
				continue
		
		# 3. Closest to Mouse
		var d = e.global_position.distance_to(mouse_pos)
		if d < min_dist:
			min_dist = d
			best = e
			
	return best

func _physics_process(delta):
	hp_label.text = str(hp_bar.value) + "/" + str(hp_bar.max_value)
	look_at(get_global_mouse_position())
	collision_shape_2d.rotation = -rotation
	player_sprite.rotation = -rotation
	
	if Global.aim_assist:
		current_target = find_best_target()
		if current_target and aim_indicator:
			aim_indicator.global_position = current_target.global_position + Vector2(0, -40)
			aim_indicator.visible = true
		elif aim_indicator:
			aim_indicator.visible = false
	elif aim_indicator:
		aim_indicator.visible = false
		current_target = null
	
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
	
	if current_target and Global.aim_assist:
		var dir = (current_target.global_position - projectile_spawn.global_position).normalized()
		# Slight homing check. Default steer is 500, we use 200 for slight.
		if projectile.has_method("setup_homing"):
			projectile.setup_homing(dir, 600.0, damage, current_target, 200.0)
		else:
			projectile.setup_straight(dir, 600.0, damage)
	else:
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
	
	# 3. Hide weapon and reset rotation when animation completes
	tween.tween_callback(weapon_sprite.hide)
	tween.tween_callback(weapon_sprite.set_rotation.bind(0))



# This new function holds the damage logic
func _apply_damage(target: Node2D) -> void:
	# We must check again if the target is still valid and in range
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
