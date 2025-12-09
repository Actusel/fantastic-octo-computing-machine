extends Area2D



var player = null

# Called when the node enters the scene tree for the first time.
func _ready():
	body_entered.connect(unlock)
	body_exited.connect(lock)
	
func unlock(body):
	if body.is_in_group("player"):
		player = body
		
func lock(body):
	if body.is_in_group("player"):
		player = null

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta):
	if player and Input.is_action_just_pressed("use"): 
		get_parent().queue_free()
