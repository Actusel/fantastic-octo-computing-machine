extends Control

@onready var inv_grid: GridContainer = $CenterContainer/GridContainer
@onready var label: Label = $weight

var player = null

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
	player = get_tree().root.find_child("player", true, false)
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
func add_to_inventory(item_data: ItemData, amount: int = 1) -> void:
	var remaining := amount

	# -------------------------------------------------
	# 1) STACK INTO EXISTING SLOTS FIRST
	# -------------------------------------------------
	if item_data.max_stack > 1:
		for slot in inv_grid.get_children():
			if not slot.filled:
				continue

			if slot.item_data != item_data:
				continue

			var space = item_data.max_stack - slot.stack_count
			if space <= 0:
				continue

			var to_add = min(space, remaining)
			slot.stack_count += to_add
			remaining -= to_add

			total_weight += item_data.weight * to_add
			_update_weight_label()

			if remaining == 0:
				_rescan_slots()
				return

	# -------------------------------------------------
	# 2) PLACE INTO EMPTY SLOTS
	# -------------------------------------------------
	for slot in inv_grid.get_children():
		if remaining == 0:
			break

		if slot.filled:
			continue

		# Weight check PER SLOT placement
		var to_place = min(item_data.max_stack, remaining)
		var added_weight = item_data.weight * to_place

		if total_weight + added_weight > max_weight:
			print("Too heavy!")
			break

		slot.fill_slot(item_data)
		slot.stack_count = to_place

		total_weight += added_weight
		remaining -= to_place
		_update_weight_label()

	# -------------------------------------------------
	# 3) FINALIZE
	# -------------------------------------------------
	if remaining > 0:
		print("Inventory full, leftover:", remaining)

	_rescan_slots()



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
