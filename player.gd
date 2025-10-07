extends CharacterBody2D

@onready var dash_cooldown = $dash_cooldown
@onready var dash_icon = $ColorRect
@onready var label = $ui/Label


const SPEED = 200.0
const dash_time = 0.2
const DASH_SPEED = 600

var dashing = false
var dash_timer: float

func dash_indicator():
	if dash_cooldown.time_left: return snapped(dash_cooldown.time_left,.01) 
	else: return "ready" 
		
		
func _physics_process(delta):
	var direction = Input.get_vector("moveleft","moveright","moveup","movedown")
	label.set_text(str(dash_indicator()))
	
	
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
		velocity.x = move_toward(velocity.x, direction.x*SPEED, 40)
		velocity.y = move_toward(velocity.y, direction.y*SPEED, 40)
	
	
	move_and_slide()
