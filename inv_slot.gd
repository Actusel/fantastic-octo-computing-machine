extends Panel
class_name ItemSlot

@onready var item_display: Sprite2D = $item_display
@onready var button: Button = $Move
@onready var drop: Button = $drop

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
@export var emtpy_texture: Texture2D = null


func _ready() -> void:
	inv = get_tree().root.find_child("inventory", true, false)
	button.pressed.connect(_on_click)
	drop.pressed.connect(_on_item_drop)
	item_display.texture = emtpy_texture


# ----------------------------------------------------------
# PUBLIC METHODS
# ----------------------------------------------------------

func fill_slot(new_item: ItemData) -> void:
	item_data = new_item
	item_display.texture = item_data.icon
	filled = true


func clear_slot() -> void:
	item_display.texture = emtpy_texture
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
	if slot_type == slot_types.inventory:
		_handle_inventory_click()
	else:
		_handle_equipment_click()

func _on_item_drop() -> void:
	if not filled:
		return

	# Ground item scene
	var ground_item_scene := preload("uid://dwbqxt7i8lf4j")  # <-- your path
	var ground_item := ground_item_scene.instantiate()

	# Assign resource data
	ground_item.item_data = item_data

	# Spawn at player position
	var player = inv.player
	if player:
		ground_item.global_position = player.global_position
	else:
		push_warning("Player not found. Dropping item at slot position.")
		ground_item.global_position = global_position

	# Add to world
	get_tree().current_scene.add_child(ground_item)

	# Remove from inventory slot
	inv.total_weight -= item_data.weight
	inv._update_weight_label()
	clear_slot()
	inv._rescan_slots()

# ----------------------------------------------------------
# LOGIC: USING AN ITEM FROM INVENTORY
# ----------------------------------------------------------

func _handle_inventory_click() -> void:
	match item_data.type:

		"food":
			# FOOD is consumed, goes directly to player
			get_tree().call_group("player", "hp_changed", item_data.strongness)
			_remove_from_inventory()
			return

		"helmet", "body", "weapon", "shield":
			_equip_item()
			return


# ----------------------------------------------------------
# LOGIC: CLICKING AN EQUIPPED ITEM (UNEQUIP)
# ----------------------------------------------------------

func _handle_equipment_click() -> void:
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
	return node if node else null
