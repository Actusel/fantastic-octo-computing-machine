extends Area2D


var inside: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	body_entered.connect(unlock)
	body_exited.connect(lock)
	
func unlock(body):
	if body.name == "player":
		inside=true
		
func lock(body):
	if body.name == "player":
		inside=false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if inside and Input.is_action_just_pressed("use"): get_parent().queue_free()
