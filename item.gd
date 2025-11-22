extends Area2D

@export var item_data: ItemData          # The resource describing this item
@onready var visual: Sprite2D = $visual

var inv: Control                          # Reference to Inventory
var inside: bool = false
var can_pickup: bool = true


func _ready():
	# Load the item icon from the resource
	if item_data and item_data.icon:
		visual.texture = item_data.icon

	body_entered.connect(_on_body_enter)
	body_exited.connect(_on_body_exit)

	# Find the inventory node (same as your previous logic)
	inv = get_tree().root.find_child("inventory", true, false)


func _on_body_enter(body):
	if body.name == "player":
		inside = true


func _on_body_exit(body):
	if body.name == "player":
		inside = false


func _physics_process(_delta: float):
	if inside and can_pickup and Input.is_action_just_pressed("use"):
		_try_pickup()


func _try_pickup():
	if not item_data:
		push_warning("Ground item missing its ItemData resource!")
		return

	# Check if inventory has space + weight room
	var new_weight = inv.total_weight + item_data.weight

	if inv.next_available_slot == -1:
		print("Inventory full!")
		return

	if new_weight > inv.max_weight:
		print("Too heavy!")
		return

	# Add to inventory
	inv.add_to_inventory(item_data)

	queue_free()
