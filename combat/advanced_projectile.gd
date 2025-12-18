extends Area2D

# --- Configuration ---
@export var speed: float = 300.0
@export var damage: float = 10.0
@export var steer_force: float = 0.0 # set > 0 for Homing

# --- State ---
enum Mode { STRAIGHT, BOOMERANG, HOMING }
var current_mode = Mode.STRAIGHT
var velocity = Vector2.ZERO
var target_node: Node2D = null # For Boomerang (Boss) or Homing (Player)
var direction: Vector2 = Vector2.ZERO # For compatibility

func _ready():
	# If using physics bodies, use body_entered. connect via editor or code:
	body_entered.connect(_on_body_entered)
	if has_node("VisibleOnScreenNotifier2D"):
		$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	
	# Compatibility initialization
	if direction != Vector2.ZERO and velocity == Vector2.ZERO:
		velocity = direction * speed
		rotation = direction.angle()

func _physics_process(delta):
	match current_mode:
		Mode.STRAIGHT:
			position += velocity * delta
			
		Mode.HOMING:
			if is_instance_valid(target_node):
				var desired = (target_node.global_position - global_position).normalized() * speed
				var steering = (desired - velocity).limit_length(steer_force * delta)
				velocity += steering
				position += velocity * delta
				rotation = velocity.angle()
			else:
				# If target dies, default to straight
				position += velocity * delta

		Mode.BOOMERANG:
			# Movement logic is handled by the Tween, so we just check collision
			# Rotation aligns with movement direction (optional, requires manual calculation)
			pass

func _on_body_entered(body):
	# Ignore shooter if needed, but for now just hit anything
	if body.has_method("take_damage"):
		body.take_damage(damage)
	elif body.has_method("hp_changed"):
		body.hp_changed(-damage)
		
	queue_free()

# --- External Setup Functions ---

# Standard linear shot
func setup_straight(dir: Vector2, spd: float, dmg: float):
	current_mode = Mode.STRAIGHT
	velocity = dir * spd
	rotation = dir.angle()
	damage = dmg

# Used for the "Rain" attack if you want them to curve slightly toward player
func setup_homing(dir: Vector2, spd: float, dmg: float, target: Node2D):
	current_mode = Mode.HOMING
	velocity = dir * spd
	target_node = target
	steer_force = 500.0 # Adjust for stronger/weaker turning
	damage = dmg

# Used for the "Bloom & Wither" attack
func set_wither_behavior(return_target: Node2D):
	current_mode = Mode.BOOMERANG
	target_node = return_target
	
	# We use a Tween to handle the complex "Out -> Stop -> Return" movement
	var tween = create_tween()
	
	# 1. Travel OUTWARD (already set by spawn velocity)
	# We simulate physics manually in tween or just tween position
	# Let's use a relative movement for the "Out" phase
	var outward_dest = global_position + (Vector2.RIGHT.rotated(rotation) * 400.0)
	
	tween.tween_property(self, "global_position", outward_dest, 1.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# 2. WAIT/HOVER
	tween.tween_interval(0.5)
	
	# 3. RETURN to Boss
	# We use a callback to find the boss's CURRENT position when the return starts
	tween.tween_callback(start_return_trip)

func start_return_trip():
	if not is_instance_valid(target_node):
		queue_free()
		return
		
	# Create a new tween for the return trip so it tracks the CURRENT boss position
	var return_tween = create_tween()
	var duration = 1.5
	
	# We tween to the boss's position. 
	# Note: If boss moves FAST, this might miss. For guaranteed hit, use physics in _process.
	# But for a pattern, tweening to the location is visually smoother.
	return_tween.tween_property(self, "global_position", target_node.global_position, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Scale damage up on return trip
	damage *= 2.0
	modulate = Color.RED # Visual feedback
	
	# Delete when it reaches the boss
	return_tween.tween_callback(queue_free)
