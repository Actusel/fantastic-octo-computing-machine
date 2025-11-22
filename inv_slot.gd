extends Panel
class_name ItemSlot

@onready var item_display: Sprite2D = $item_display
@onready var button: Button = $Button

var inv: Control
var filled: bool = false
var equipped: bool = false

# The item stored in this slot
var item_data: ItemData = null

enum slot_types {
	inventory,
	shield,
	body,
	weapon,
	helmet
}

# This slotâs role: "inventory", "helmet", "weapon", "body", "shield"
@export var slot_type: slot_types = slot_types.inventory


func _ready() -> void:
	inv = get_tree().root.find_child("inventory", true, false)
	button.pressed.connect(_on_click)


# ----------------------------------------------------------
# PUBLIC METHODS
# ----------------------------------------------------------

func fill_slot(new_item: ItemData) -> void:
	item_data = new_item
	item_display.texture = item_data.icon
	filled = true


func clear_slot() -> void:
	item_display.texture = null
	filled = false
	equipped = false
	item_data = null
	inv._rescan_slots()


# ----------------------------------------------------------
# CLICK HANDLING
# ----------------------------------------------------------

func _on_click() -> void:
	if not filled:
		return
	print(slot_type)
	if slot_type == slot_types.inventory:
		_handle_inventory_click()
	else:
		_handle_equipment_click()


# ----------------------------------------------------------
# LOGIC: USING AN ITEM FROM INVENTORY
# ----------------------------------------------------------

func _handle_inventory_click() -> void:
	match item_data.type:

		"food":
			# FOOD is consumed, goes directly to player
			Global.hp_changed.emit(item_data.strongness)
			_remove_from_inventory()
			return

		"helmet", "body", "weapon", "shield":
			_equip_item()
			return


# ----------------------------------------------------------
# LOGIC: CLICKING AN EQUIPPED ITEM (UNEQUIP)
# ----------------------------------------------------------

func _handle_equipment_click() -> void:
	print(inv.next_available_slot)
	if inv.next_available_slot != -1:
		# Unequip to first free inventory slot
		var target_slot = inv.inv_grid.get_child(inv.next_available_slot)
		target_slot.fill_slot(item_data)
		inv._update_weight_label()
		inv._rescan_slots()
		clear_slot()


# ----------------------------------------------------------
# INTERNAL HELPERS
# ----------------------------------------------------------

func _equip_item() -> void:
	var target_slot: ItemSlot = _find_equipment_slot_for(item_data.type)

	if not target_slot:
		print("No matching equipment slot for item type:", item_data.type)
		return

	if target_slot.filled:
		print("Slot already filled!")
		return

	# Move into the equipment slot
	target_slot.fill_slot(item_data)
	clear_slot()

	# Weight stays the same since equipment still counts


func _remove_from_inventory() -> void:
	# Remove item entirely from inventory
	inv.total_weight -= item_data.weight
	inv._update_weight_label()
	clear_slot()
	inv._rescan_slots()


func _find_equipment_slot_for(type_str: String) -> ItemSlot:
	# Finds slot under inventory root
	var node := inv.find_child(type_str, true, false)
	print(node)
	return node if node else null
