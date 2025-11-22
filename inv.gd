extends Control

@onready var inv_grid: GridContainer = $CenterContainer/GridContainer
@onready var label: Label = $weight

const INV_SLOT = preload("uid://bgstnt0syqkyr")

var total_slots: int = 3
var total_weight: int = 0
var max_weight: int = 50

var next_available_slot: int = -1
var available_slots: int = 0


# ---------------------------------------------------------
# INITIALIZATION
# ---------------------------------------------------------
func _ready() -> void:
	_update_stats()
	_initialize_slots()
	_update_weight_label()


func _update_stats() -> void:
	total_slots = min(3 + round(Global.leg), 30)
	max_weight = 500 + round(Global.leg * 10)


func _initialize_slots() -> void:
	# Clear existing (if panel is rebuilt)
	for c in inv_grid.get_children():
		c.queue_free()

	for i in total_slots:
		inv_grid.add_child(INV_SLOT.instantiate())

	# Recalculate slot availability
	_rescan_slots()


# ---------------------------------------------------------
# INVENTORY MANAGEMENT
# ---------------------------------------------------------
func add_to_inventory(item_data: ItemData) -> void:
	var weight := item_data.weight
	var new_weight := total_weight + weight

	if next_available_slot == -1:
		print("No inventory space!")
		return

	if new_weight > max_weight:
		print("Too heavy!")
		return

	var slot := inv_grid.get_child(next_available_slot)
	slot.fill_slot(item_data)

	total_weight = new_weight
	_update_weight_label()

	# Refresh available slot data AFTER adding
	_rescan_slots()


func drop_from_inventory(_item_data: ItemData) -> void:
	# Implement later: spawn the world pickup
	pass


# ---------------------------------------------------------
# SLOT SCANNING (Optimized)
# ---------------------------------------------------------
func _rescan_slots() -> void:
	available_slots = 0
	next_available_slot = -1

	var child_count := inv_grid.get_child_count()
	for i in child_count:
		var slot = inv_grid.get_child(i)
		if not slot.filled:
			available_slots += 1
			if next_available_slot == -1:
				next_available_slot = i


# ---------------------------------------------------------
# UI + INPUT
# ---------------------------------------------------------
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_home"):
		toggle_inv()


func toggle_inv() -> void:
	visible = not visible


func _update_weight_label() -> void:
	label.text = "carrying %d/%d kg" % [total_weight, max_weight]
