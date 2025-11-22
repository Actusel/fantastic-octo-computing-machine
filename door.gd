extends Area2D


var inside: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	body_entered.connect(unlock)
	body_exited.connect(lock)
	
func unlock(body):
	if body.is_in_group("player"):
		inside=true
		
func lock(body):
	if body.is_in_group("player"):
		inside=false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta):
	if inside: get_parent().queue_free()
