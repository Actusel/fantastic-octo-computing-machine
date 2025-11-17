extends CharacterBody2D

@onready var dash_cooldown = $dash_cooldown
@onready var dash_icon = $ColorRect
@onready var label = $ui/Label
@onready var inventory: Control = $ui/inventory
@onready var label_2: Label = $ui/Label2
@onready var hp_bar: ProgressBar = $ui/HP


#var dragging_body : RigidBody2D = null
#var drag_radius = 50.0
#var drag_strength = 4000.0
#var drag_axis: String

const SPEED = 200.0
const dash_time = 0.2
const DASH_SPEED = 600
const push_str = 100
var dashing = false
var dash_timer: float
var dragging = false
var max_hp
var HP: float 

func _ready() -> void:
	label_2.text = str(Global.leg)
	max_hp = hp_bar.max_value
	max_hp = 100 + Global.back*10
	HP = hp_bar.value

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
		
	#if Input.is_action_just_pressed("drag"): dragging = true
	#if Input.is_action_just_released("drag"): dragging = false
	
	move_and_slide()
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		if body.is_in_group("movable"):
			body.apply_central_impulse(-collision.get_normal()*push_str)
			
#			note: system below is very bad and unintuative, but still here because it could be used as base for a better version
#			if dragging: 
#				dragging_body = body
#				var diff = dragging_body.global_position - global_position
#				if abs(diff.x) > abs(diff.y):
#					drag_axis = "x"   # player is left/right → drag horizontally
#				else: 
#					drag_axis = "y"   # player is above/below → drag vertically
#
#
#	if dragging_body and dragging:
#		var box_pos = dragging_body.global_position
#		var target = box_pos
#		var dist = global_position.distance_to(dragging_body.global_position)
#		if drag_axis == "x":
#			target.x = global_position.x
#		elif drag_axis == "y":
#			target.y = global_position.y
#		var pull = (target - box_pos)
#		print(pull.length())
#		if pull.length() > .5:
#			if dist < drag_radius:
#				dragging_body.apply_central_force(pull.normalized() * drag_strength)
#			else: dragging_body = null
#	else: dragging_body = null
