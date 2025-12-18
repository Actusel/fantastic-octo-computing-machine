extends Area2D

@export var item_data: ItemData          # The resource describing this item
@export var amount: int = 1              # The amount of this item (for stackable items)
@onready var visual: Sprite2D = $visual
@onready var amount_label: Label = $AmountLabel

var inside: bool = false
var can_pickup: bool = true


func _ready():
	# Load the item icon from the resource
	if item_data and item_data.icon and amount_label:
		visual.texture = item_data.icon
		amount_label.text = str(amount)

	body_entered.connect(_on_body_enter)
	body_exited.connect(_on_body_exit)


func _on_body_enter(body):
	if body.is_in_group("player"):
		inside = true


func _on_body_exit(body):
	if body.is_in_group("player"):
		inside = false


func _physics_process(_delta: float):
	if inside and can_pickup and Input.is_action_just_pressed("use"):
		_try_pickup()


func _try_pickup():
	if not item_data:
		push_warning("Ground item missing its ItemData resource!")
		return

	# Attempt to add to Global inventory
	# Global.add_item returns the amount that was NOT added (leftover)
	var leftover = Global.add_item(item_data, amount)

	if leftover == 0:
		# Successfully picked up everything
		queue_free()
	else:
		# Could not pick up everything
		amount = leftover
		print("Inventory full or too heavy!")
