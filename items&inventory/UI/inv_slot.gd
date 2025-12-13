extends Panel
class_name ItemSlot

@onready var item_display: Sprite2D = $item_display
@onready var button: Button = $Move
@onready var drop: Button = $drop
@onready var label: Label = $Label

var inv: Control
var filled: bool = false
var equipped: bool = false
var stack_count: int = 0


# The item stored in this slot
var item_data: ItemData = null

enum slot_types {
	inventory,
	offhand,
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

func fill_slot(new_item: ItemData, amount: int = 1) -> int:
	# returns leftover amount if stacking fails

	if not filled:
		item_data = new_item
		stack_count = min(amount, item_data.max_stack)
		item_display.texture = item_data.icon
		filled = true
		return amount - stack_count

	# stacking
	if item_data == new_item and item_data.max_stack > 1:
		var space := item_data.max_stack - stack_count
		var to_add = min(space, amount)
		stack_count += to_add
		return amount - to_add

	return amount




func clear_slot() -> void:
	item_display.texture = emtpy_texture
	filled = false
	stack_count = 0
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
	_remove_from_inventory()

# ----------------------------------------------------------
# LOGIC: USING AN ITEM FROM INVENTORY
# ----------------------------------------------------------

func _handle_inventory_click() -> void:
	match item_data.type:

		"food":
			get_tree().call_group("player", "hp_changed", item_data.strongness)
			_consume_from_stack(1)
			return

		"helmet", "body", "weapon", "shield", "arrow":
			_try_equip_from_inventory()
			return



# ----------------------------------------------------------
# LOGIC: CLICKING AN EQUIPPED ITEM (UNEQUIP)
# ----------------------------------------------------------

func _handle_equipment_click() -> void:
	if not filled:
		return
	if inv.next_available_slot == -1:
		return
	

	var amount := stack_count

	# Return items to inventory using stacking logic
	inv.add_to_inventory(item_data, amount)
	
	_on_unequipped(amount)


	_remove_from_inventory()

# ----------------------------------------------------------
# INTERNAL HELPERS
# ----------------------------------------------------------

func _try_equip_from_inventory() -> void:
	var target_slot := _find_equipment_slot_for(item_data.type)
	if not target_slot:
		print("No equipment slot for:", item_data.type)
		return
	
	print(target_slot.item_data)
	# Amount to move:
	# armor / weapon = 1
	# arrow = whole stack
	var amount := stack_count if item_data.type == "arrow" else 1

	var leftover := target_slot.fill_slot(item_data, amount)

	var moved := amount - leftover
	if moved <= 0:
		return

	# Apply effects
	_on_equipped(moved)

	# Remove from inventory stack
	stack_count -= moved
	if stack_count <= 0:
		clear_slot()

func _on_equipped(_amount: int) -> void:
	match item_data.type:

		"helmet", "body":
			get_tree().call_group("player", "max_hp_changed", item_data.strongness)

		"weapon":
			get_tree().call_group("player", "change_weapon", item_data)

		# arrows / shield have no immediate effect

func _on_unequipped(_amount: int) -> void:
	match item_data.type:

		"helmet", "body":
			get_tree().call_group("player", "max_hp_changed", -item_data.strongness)

		"weapon":
			get_tree().call_group("player", "clear_weapon")


func _remove_from_inventory() -> void:
	# Remove item entirely from inventory
	inv.total_weight -= item_data.weight * stack_count
	inv._update_weight_label()
	clear_slot()
	inv._rescan_slots()

func _consume_from_stack(amount: int) -> void:
	stack_count -= amount
	inv.total_weight -= item_data.weight * amount
	inv._update_weight_label()

	if stack_count <= 0:
		clear_slot()

	inv._rescan_slots()



func _find_equipment_slot_for(type_str: String) -> ItemSlot:
	var node = null
	if type_str == "shield" or type_str == "arrow":
		node = inv.find_child("offhand", true, false)
	else:
		node = inv.find_child(type_str, true, false)
	return node if node else null

func _process(_delta: float) -> void:
	label.text = str(stack_count)
