extends Panel
class_name ItemSlot

@onready var item_display: Sprite2D = $item_display
@onready var button: Button = $Move
@onready var drop: Button = $drop
@onready var label: Label = $Label

var inv: Control
var filled: bool = false
var stack_count: int = 0
var item_data: ItemData = null

# Index in Global.inventory (only for inventory slots)
var slot_index: int = -1

enum slot_types {
	inventory,
	offhand,
	body,
	weapon,
	helmet
}

@export var slot_type: slot_types = slot_types.inventory
@export var emtpy_texture: Texture2D = null

func _ready() -> void:
	inv = get_tree().root.find_child("inventory", true, false)
	button.pressed.connect(_on_click)
	drop.pressed.connect(_on_item_drop)
	item_display.texture = emtpy_texture

# Called by inv.gd (View)
func update_slot(new_item: ItemData, count: int) -> void:
	item_data = new_item
	stack_count = count
	filled = true
	item_display.texture = item_data.icon
	# label updated in _process

func fill_slot(new_item: ItemData, amount: int = 1) -> int:
	# Legacy support / Fallback
	update_slot(new_item, amount)
	return 0

func clear_slot() -> void:
	item_display.texture = emtpy_texture
	filled = false
	stack_count = 0
	item_data = null

func _on_click() -> void:
	if not filled: return
	
	if slot_type == slot_types.inventory:
		Global.use_item(slot_index)
	else:
		# Determine key from slot_type
		var key = _get_equip_key()
		if key != "":
			Global.unequip_item(key)

func _on_item_drop() -> void:
	if not filled: return
	
	# Drop logic (spawn in world)
	var ground_item_scene := preload("uid://dwbqxt7i8lf4j")
	var ground_item := ground_item_scene.instantiate()
	ground_item.item_data = item_data
	
	var player = inv.player
	if player:
		ground_item.global_position = player.global_position
	else:
		ground_item.global_position = global_position
	
	get_tree().current_scene.add_child(ground_item)
	
	# Remove from data
	if slot_type == slot_types.inventory:
		Global.remove_item(slot_index, stack_count)
	else:
		var key = _get_equip_key()
		if key != "":
			# Unequip without adding to inventory (effectively delete/drop)
			# We need a way to clear equipment without adding to inventory.
			# For now, let's just set it to null in Global manually or add a helper.
			Global.equipment[key] = null
			Global._unequip_effect(item_data)
			Global.emit_signal("inventory_updated")

func _get_equip_key() -> String:
	match slot_type:
		slot_types.helmet: return "helmet"
		slot_types.body: return "body"
		slot_types.weapon: return "weapon"
		slot_types.offhand: return "offhand"
	return ""

func _process(_delta: float) -> void:
	if filled:
		label.text = str(stack_count)
	else:
		label.text = ""
