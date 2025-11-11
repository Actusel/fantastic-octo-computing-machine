extends Control

@onready var inv_grid: GridContainer = $ColorRect/GridContainer


var available_slots = 0
var next_available_slot


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var found_first = false
	for child in inv_grid.get_child_count():
		if not inv_grid.get_child(child).filled:
			available_slots+=1
			if not found_first: 
				next_available_slot = child
				found_first = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_home"):
		toggle_inv()
		print(next_available_slot)
		print(available_slots)


func toggle_inv():
	if visible:
		visible=false
	else:
		visible=true

func add_to_inventory(item):
	if not next_available_slot==null: 
		var item_texture = item.get_child(0).texture
		inv_grid.get_child(next_available_slot).fill_slot(item_texture)
		if next_available_slot<11: next_available_slot+=1 
		else: next_available_slot=null
