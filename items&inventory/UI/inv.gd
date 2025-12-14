extends Control

@onready var inv_grid: GridContainer = $CenterContainer/GridContainer
@onready var label: Label = $weight

var player = null

const INV_SLOT = preload("uid://bgstnt0syqkyr")

# ---------------------------------------------------------
# INITIALIZATION
# ---------------------------------------------------------
func _ready() -> void:
	player = get_tree().root.find_child("player", true, false)
	
	if not Global.inventory:
		Global._resize_inventory()
	
	# Connect to Global signal
	if not Global.inventory_updated.is_connected(_on_inventory_updated):
		Global.inventory_updated.connect(_on_inventory_updated)
	
	# Initial render
	_on_inventory_updated()


# ---------------------------------------------------------
# INVENTORY MANAGEMENT (View Update)
# ---------------------------------------------------------
func _on_inventory_updated() -> void:
	_update_slots()
	_update_equipment_slots()
	_update_weight_label()

func _update_equipment_slots() -> void:
	var map = {
		"helmet": "helmet",
		"body": "body",
		"weapon": "weapon",
		"offhand": "offhand"
	}
	
	for key in map:
		var node_name = map[key]
		var slot_node = find_child(node_name, true, false)
		if slot_node and slot_node.has_method("update_slot"):
			var data = Global.equipment[key]
			if data:
				slot_node.update_slot(data["item"], data["count"])
			else:
				slot_node.clear_slot()

func _update_slots() -> void:
	# Ensure we have the correct number of slots
	var current_slots = inv_grid.get_child_count()
	var target_slots = Global.inventory.size()
	
	# Add needed slots
	if current_slots < target_slots:
		for i in range(target_slots - current_slots):
			var slot = INV_SLOT.instantiate()
			inv_grid.add_child(slot)
	
	# Remove extra slots (if any)
	elif current_slots > target_slots:
		for i in range(current_slots - target_slots):
			inv_grid.get_child(current_slots - 1 - i).queue_free()
	
	# Update slot data
	for i in range(target_slots):
		var slot_ui = inv_grid.get_child(i)
		var slot_data = Global.inventory[i]
		
		# We will add 'slot_index' to inv_slot.gd
		if "slot_index" in slot_ui:
			slot_ui.slot_index = i 
		
		if slot_data != null:
			# We will add 'update_slot' to inv_slot.gd, or use fill_slot
			if slot_ui.has_method("update_slot"):
				slot_ui.update_slot(slot_data["item"], slot_data["count"])
			else:
				# Fallback to old method if not yet updated (though we will update it)
				slot_ui.clear_slot()
				slot_ui.fill_slot(slot_data["item"], slot_data["count"])
		else:
			slot_ui.clear_slot()

func add_to_inventory(item_data: ItemData, amount: int = 1) -> void:
	# Delegate to Global
	var leftover = Global.add_item(item_data, amount)
	if leftover > 0:
		print("Inventory full or heavy, leftover:", leftover)

# ---------------------------------------------------------
# UI + INPUT
# ---------------------------------------------------------
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_home"):
		toggle_inv()


func toggle_inv() -> void:
	visible = not visible


func _update_weight_label() -> void:
	label.text = "carrying %d/%d kg" % [Global.get_total_weight(), Global.get_max_weight()]

# Compatibility property for scripts accessing next_available_slot
var next_available_slot: int:
	get:
		for i in range(Global.inventory.size()):
			if Global.inventory[i] == null:
				return i
		return -1
