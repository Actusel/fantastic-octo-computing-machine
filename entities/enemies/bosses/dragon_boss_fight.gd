extends CharacterBody2D

# --- Configuration & Scaling ---
@export var bullet_scene: PackedScene # Drag your bullet.tscn here in the Inspector
@export var laser_scene: PackedScene
@export var level: int = Global.level
@export var base_damage: float = 10.0

# --- State Variables ---
enum Stage { STAGE_1, TRANSITION, STAGE_2 }
var current_stage = Stage.STAGE_1
var max_hp: float = 1000.0
var current_hp: float = 1000.0
var dash_duration = 0.6

# --- Timer References (Add these nodes as children of the Boss) ---
@onready var attack_timer = $AttackTimer
@onready var movement_tween: Tween
@onready var hp_bar: ProgressBar = $hp_bar

# --- Difficulty Scaling Logic ---
var bullet_count: int
var bullet_damage: float

func _ready():
	calculate_difficulty_stats()
	current_hp = max_hp
	start_attack_cycle()
	hp_bar.max_value = max_hp
	hp_bar.value = max_hp

func calculate_difficulty_stats():
	# CLAMP bullet count: Starts at 5, maxes at 30.
	# We map level 1 -> 5 bullets, and level 50 (for example) -> 30 bullets.
	# Adjust the divisor (2.0) to change how fast it scales.
	var raw_count = 5 + (level * 0.5) 
	bullet_count = clampi(int(raw_count), 5, 30)
	
	# LINEAR damage scaling: No cap.
	# Level 1 = Base, Level 10 = Base + 20, etc.
	bullet_damage = base_damage + (level * 2.0)
	
	print("Boss Level: %s | Bullets: %s | Damage: %s" % [level, bullet_count, bullet_damage])

# --- Damage & Phase Transition ---
func hp_changed(amount: float):
	if current_stage == Stage.TRANSITION: return
	
	current_hp += amount
	hp_bar.value = current_hp
	print(current_hp)
	
	# Check for Phase Transition (50% HP)
	if current_stage == Stage.STAGE_1 and current_hp <= (max_hp * 0.5):
		start_transition()
	
	if current_hp <= 0:
		die()

func start_transition():
	current_stage = Stage.TRANSITION
	attack_timer.stop()
	
	# 1. Clear existing bullets (Optional - requires a group "enemy_bullets")
	get_tree().call_group("enemy_projectile", "queue_free")
	
	# 2. Visuals: Shake and Flash
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.5)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	
	await tween.finished
	
	# 3. Start Stage 2
	current_stage = Stage.STAGE_2
	# Stage 2 is faster
	attack_timer.start()

# --- Attack Management ---
func start_attack_cycle():
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.start()

func _on_attack_timer_timeout():
	if current_stage == Stage.STAGE_1:
		# Pick a random pattern for Stage 1
		var roll = randi() % 3
		match roll:
			0: attack_clockwork()
			1: attack_pulse()
			2: attack_wedge()
			
	elif current_stage == Stage.STAGE_2:
		# Move randomly before attacking in Stage 2
		dash_randomly()
		
		await get_tree().create_timer(dash_duration).timeout
		var roll = randi() % 3
		match roll:
			0: attack_rain()
			1: attack_bloom_wither()
			2: attack_laser()

# --- STAGE 1 ATTACKS (Geometric) ---

func attack_pulse():
	# Fires a perfect ring. Uses the scaled 'bullet_count'.
	var angle_step = 2 * PI / bullet_count
	
	for i in range(bullet_count):
		var angle = i * angle_step
		var direction = Vector2(cos(angle), sin(angle))
		spawn_bullet(global_position, direction, 200)

func attack_clockwork():
	# Fires 4 rotating streams. 
	# To make this continuous, you would usually use a separate timer, 
	# but here is a burst version.
	var spines = 4
	var bullets_per_spine = 5
	
	for i in range(bullets_per_spine):
		await get_tree().create_timer(0.1).timeout # Delay between bullets in the stream
		for s in range(spines):
			var angle = (s * (2 * PI / spines)) + (i * 0.1) # Add rotation offset
			var direction = Vector2(cos(angle), sin(angle))
			spawn_bullet(global_position, direction, 250)

func attack_wedge():
	# Targeted V-shape at player
	var player = get_tree().get_first_node_in_group("player")
	if not player: return
	
	var aim_dir = (player.global_position - global_position).normalized()
	var base_angle = aim_dir.angle()
	var spread = 0.1 # Radians
	
	# Fire 3 bullets: Center, Left, Right
	spawn_bullet(global_position, aim_dir, 350)
	spawn_bullet(global_position, Vector2(cos(base_angle - spread), sin(base_angle - spread)), 350)
	spawn_bullet(global_position, Vector2(cos(base_angle + spread), sin(base_angle + spread)), 350)

# --- STAGE 2 ATTACKS (Chaotic) ---

func attack_rain():
	# Spawns bullets from top of screen
	var screen_size = get_viewport_rect().size
	# Denser rain based on level
	var rain_count = bullet_count
	
	for i in range(rain_count):
		var spawn_x = randf_range(0, screen_size.x)
		var spawn_pos = Vector2(spawn_x, 0) # Top of screen
		var direction = Vector2(0, 1) # Down
		# Random speeds for chaos
		var speed = randf_range(200, 450)
		spawn_bullet(spawn_pos, direction, speed)

func attack_bloom_wither():
	for i in range(bullet_count):
		var angle = randf() * 2 * PI
		
		var b = bullet_scene.instantiate()
		b.global_position = global_position
		b.rotation = angle
		
		# Initialize standard data
		b.damage = bullet_damage
		
		# Trigger the specific behavior directly
		b.set_wither_behavior(self) # Pass 'self' so it returns to the boss
		
		get_parent().add_child(b)

func attack_laser():
	# Face player first
	var player = get_tree().get_first_node_in_group("player")
	if player:
		look_at(player.global_position)

	# Instance the laser as a child of the BOSS (so it moves/rotates with him)
	var laser = laser_scene.instantiate()
	add_child(laser)
	laser.rotation = 0 # Face forward relative to boss
	laser.fire_beam(2) # Lasts 2 seconds
	
	# While laser is firing, rotate the boss to sweep the room
	var sweep_tween = create_tween()
	var sweep_angle = PI / 2 # 90 degrees
	var start_rot = rotation
	
	# Sweep down then up
	sweep_tween.tween_property(self, "rotation", start_rot + sweep_angle, 1.5)
	sweep_tween.tween_property(self, "rotation", start_rot - sweep_angle, 1.5)
	# Reset rotation to 0 after attack
	sweep_tween.tween_property(self, "rotation", 0.0, 0.5)

# --- Helper Functions ---

func dash_randomly():
	var screen = get_viewport_rect().size
	# Keep boss away from edges (padding 100px)
	var target = Vector2(randf_range(100, screen.x - 100), randf_range(100, screen.y - 100))
	
	if movement_tween: movement_tween.kill()
	movement_tween = create_tween()	
	movement_tween.tween_property(self, "global_position", target, dash_duration).set_trans(Tween.TRANS_ELASTIC)


func spawn_bullet(pos: Vector2, dir: Vector2, speed: float, mode_info = {}) -> Node:
	var b = bullet_scene.instantiate()
	b.global_position = pos
	# Bullet script handles movement, we just setup data
	
	# Standard setup
	if b.has_method("setup_straight"):
		b.setup_straight(dir, speed, bullet_damage)
		
	# Special setup based on mode_info
	if mode_info.has("homing_target"):
		b.setup_homing(dir, speed, bullet_damage, mode_info.homing_target)
		
	get_parent().add_child(b)
	return b

func die():
	Global.level+=1
	get_tree().change_scene_to_file("res://maze.tscn")
	queue_free()
