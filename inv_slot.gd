extends Panel

class_name item_slot

@onready var item_display: Sprite2D = $item_display
@onready var button: Button = $Button

var inv
var hp_bar

enum type_list {
	helmet,
	body,
	food,
	weapon,
	shield
}

enum slot {
	helmet,
	weapon,
	inventory,
	body,
	shield
}

@export var item_type: type_list
@export var weight: int = 15
@export var strongness: float = 10
@export var slot_type: slot = slot.inventory

var shield_slot
var body_slot
var weapon_slot
var helmet_slot

var filled = false
var equipped = false

func _ready() -> void:
	inv = get_tree().root.find_child("inventory", true, false)
	shield_slot = inv.find_child("shield")
	body_slot = inv.find_child("body")
	weapon_slot = inv.find_child("weapon")
	helmet_slot = inv.find_child("helmet")
	button.pressed.connect(_on_item_clicked)
	
func _on_item_clicked():
	print(shield_slot.filled)
	if slot_type == slot.inventory:
		_handle_inventory_clicked()
	else: 
		_handle_equipped_click()

func _handle_inventory_clicked():
	match item_type:
		type_list.body: 
			if not body_slot.filled:
				body_slot.fill_slot(item_display.texture, weight, type_list.body)
				inv.update_inv(inv.total_weight+weight)
				remove_slot()
		type_list.helmet: 
			if not helmet_slot.filled:
				helmet_slot.fill_slot(item_display.texture, weight, type_list.helmet)
				inv.update_inv(inv.total_weight+weight)
				remove_slot()
		type_list.food: 
			inv.eat(strongness)
			remove_slot()
		type_list.weapon: 
			if not weapon_slot.filled:
				weapon_slot.fill_slot(item_display.texture, weight, type_list.weapon)
				inv.update_inv(inv.total_weight+weight)
				remove_slot()
		type_list.shield: 
			if not shield_slot.filled:
				shield_slot.fill_slot(item_display.texture, weight, type_list.shield)
				inv.update_inv(inv.total_weight+weight)
				remove_slot()

func _handle_equipped_click():
	if inv.next_available_slot != null:
			inv.inv_grid.get_child(inv.next_available_slot).fill_slot(item_display.texture, weight, item_type)
			inv.update_inv(inv.total_weight+weight)
			remove_slot()

func remove_slot():
	item_display.texture = null
	filled = false
	inv.update_inv(inv.total_weight-weight)
	weight = 0

func fill_slot(texture: Texture2D, new_weight, new_item_type):
	item_display.texture = texture
	weight = new_weight
	filled = true
	item_type = new_item_type
	if slot_type == slot.inventory: equipped = false
	else: equipped = true
