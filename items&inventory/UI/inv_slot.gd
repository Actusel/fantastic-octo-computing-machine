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

static var dragged_slot: ItemSlot = null

func _ready() -> void:
	inv = get_tree().root.find_child("inventory", true, false)
	button.pressed.connect(_on_click)
	drop.pressed.connect(_on_item_drop)
	item_display.texture = emtpy_texture
	
	# Ensure ColorRect doesn't block mouse events
	if has_node("ColorRect"):
		get_node("ColorRect").mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Enable tooltip system (needs non-empty text to trigger _make_custom_tooltip in some cases)
	tooltip_text = " "
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
	var player = inv.player
	var drop_pos = global_position
	if player:
		drop_pos = player.global_position
	
	# Spawn multiple items for the stack
	for i in range(stack_count):
		var ground_item := ground_item_scene.instantiate()
		ground_item.item_data = item_data
		ground_item.global_position = drop_pos + Vector2(randf_range(-10, 10), randf_range(-10, 10))
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

func _get_drag_data(at_position: Vector2):
	if not filled: return null
	
	dragged_slot = self
	
	var preview = TextureRect.new()
	preview.texture = item_display.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(50, 50)
	preview.modulate.a = 0.8
	set_drag_preview(preview)
	
	return {
		"source_slot": self,
		"item_data": item_data,
		"slot_type": slot_type,
		"slot_index": slot_index,
		"equip_key": _get_equip_key()
	}

func _can_drop_data(at_position: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("source_slot"):
		return false
	
	# Can always drop into inventory slots (swapping/moving handled in drop)
	if slot_type == slot_types.inventory:
		return true
		
	# For equipment slots, check if item type matches
	var item = data["item_data"]
	var key = _get_equip_key()
	
	if key == "helmet" and item.type == "helmet": return true
	if key == "body" and item.type == "body": return true
	if key == "weapon" and item.type == "weapon": return true
	if key == "offhand" and item.type in ["shield", "arrow"]: return true
	
	return false

func _drop_data(at_position: Vector2, data) -> void:
	
	# Case 1: Dragging from Inventory
	if data["slot_type"] == slot_types.inventory:
		if slot_type == slot_types.inventory:
			# Inv -> Inv
			Global.drag_move_inventory_to_inventory(data["slot_index"], slot_index)
		else:
			# Inv -> Equip
			Global.drag_inventory_to_equip(data["slot_index"], _get_equip_key())
			
	# Case 2: Dragging from Equipment
	else:
		if slot_type == slot_types.inventory:
			# Equip -> Inv
			Global.drag_equip_to_inventory(data["equip_key"], slot_index)
		else:
			# Equip -> Equip (not really supported/needed but safe to ignore)
			pass

func _notification(what):
	if what == NOTIFICATION_DRAG_BEGIN:
		var data = get_viewport().gui_get_drag_data()
		if _can_drop_data(Vector2.ZERO, data):
			if has_node("ColorRect"):
				get_node("ColorRect").modulate = Color(0.5, 1.0, 0.5, 0.5) # Green tint
				
	elif what == NOTIFICATION_DRAG_END:
		if has_node("ColorRect"):
			get_node("ColorRect").modulate = Color(1, 1, 1, 1) # Reset color
			
		if dragged_slot == self:
			if not is_drag_successful():
				var mouse_pos = get_global_mouse_position()
				# Check if mouse is outside the inventory UI
				if inv and is_instance_valid(inv):
					var inv_rect = inv.get_global_rect()
					if not inv_rect.has_point(mouse_pos):
						_on_item_drop()
			dragged_slot = null

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if Input.is_key_pressed(KEY_SHIFT):
				_on_click()
				accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if filled and event.is_action_pressed("drop_item"):
		if get_global_rect().has_point(get_global_mouse_position()):
			_on_item_drop()
			get_viewport().set_input_as_handled()

func _make_custom_tooltip(for_text):
	if not filled or item_data == null: return null
	
	var container = VBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = item_data.item_name
	container.add_child(name_label)
	
	var type_label = Label.new()
	type_label.text = "Type: " + item_data.type
	container.add_child(type_label)
	
	var stats_label = Label.new()
	stats_label.text = "Weight: %d\nStack: %d/%d" % [item_data.weight, stack_count, item_data.max_stack]
	if item_data.strongness != 0:
		stats_label.text += "\nPower: " + str(item_data.strongness)
	container.add_child(stats_label)
	
	var hint_label = Label.new()
	hint_label.text = "\nShift+Click to Use/Equip\nPress 'G' to Drop"
	hint_label.modulate = Color(0.7, 0.7, 0.7)
	container.add_child(hint_label)
	
	return container

func _process(_delta: float) -> void:
	if filled:
		label.text = str(stack_count)
	else:
		label.text = ""
