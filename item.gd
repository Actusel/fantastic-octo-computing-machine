extends Area2D

var inv

var inside: bool = false

enum type_list {
	helmet,
	body,
	food,
	weapon,
	shield
}

@export var item_name = "default"
@export var item_type: type_list
@export var weight: int = 15
@export var strongness = 2

var can_pickup = true

# Called when the node enters the scene tree for the first time.
func _ready():
	body_entered.connect(unlock)
	body_exited.connect(lock)
	inv = get_tree().root.find_child("inventory", true, false)
	
func unlock(body):
	if body.name == "player":
		inside=true

func lock(body):
	if body.name == "player":
		inside=false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta):
	if inside and Input.is_action_just_pressed("use") and can_pickup: 
		if not inv.next_available_slot==null and inv.total_weight+weight<=inv.max_weight:
			inv.add_to_inventory(self)
			queue_free()
		else: print("not enough space")
