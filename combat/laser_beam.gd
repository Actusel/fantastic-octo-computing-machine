extends RayCast2D

@onready var line = $Line2D
@export var damage_per_tick: float = 5.0

var is_firing = false

func _ready():
	# Start invisible and narrow
	line.width = 0
	enabled = false
	set_physics_process(false)

func fire_beam(duration: float):
	is_firing = true
	set_physics_process(true)
	enabled = true
	
	# 1. Telegraph (Skinny warning line)
	var tween = create_tween()
	tween.tween_property(line, "width", 5.0, 0.5) # Warning beam
	tween.tween_property(line, "default_color", Color(1, 0, 0, 0.5), 0.5) 
	
	# 2. FIRE (Thick damage beam)
	await tween.finished
	var fire_tween = create_tween()
	fire_tween.tween_property(line, "width", 60.0, 0.2).set_trans(Tween.TRANS_ELASTIC)
	fire_tween.tween_property(line, "default_color", Color(1, 0, 0, 1), 0.2)
	
	# 3. Sustain and Rotate (Handled by Boss rotation, but we handle damage)
	await get_tree().create_timer(duration).timeout
	
	# 4. Fade out
	var fade_tween = create_tween()
	fade_tween.tween_property(line, "width", 0.0, 0.3)
	await fade_tween.finished
	queue_free()

func _physics_process(_delta):
	if not is_firing: return
	
	# RayCast Logic
	# Cast ray to a long distance
	target_position = Vector2.RIGHT * 2000 
	
	if is_colliding():
		var hit_obj = get_collider()
		var hit_point = get_collision_point()
		
		# Visually stop the line at the hit point
		line.points[1] = to_local(hit_point)
		
		if hit_obj.is_in_group("player") and hit_obj.has_method("hp_changed"):
			# Damage is applied every frame, so keep the number low!
			hit_obj.hp_changed(-damage_per_tick)
	else:
		# If hitting nothing, draw line to max distance
		line.points[1] = target_position
