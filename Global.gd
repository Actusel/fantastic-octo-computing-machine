extends Node

signal game_started
signal inventory_updated

var level: int

# Inventory Data
# Each element is null or { "item": ItemData, "count": int }
var inventory: Array = [] 
var equipment: Dictionary = {
	"helmet": null,
	"body": null,
	"weapon": null,
	"offhand": null
}

var graph_data := {} 
var stamina = 0.0
var leg = 0.0
var arm = 0.0
var back = 0.0

func update(new_data):
	graph_data = new_data
	stamina = _find_max_y(graph_data["stamina"])
	leg = _find_max_y(graph_data["leggies"])
	arm = _find_max_y(graph_data["armstrong"])
	_resize_inventory()
	

func _find_max_y(series: Array) -> float:
	if series.is_empty():
		return 0.0
	var max_val = series[0]["y"]
	for p in series:
		if p["y"] > max_val:
			max_val = p["y"]
	return max_val

# --- Inventory Logic ---

func _resize_inventory():
	var target_size = int(min(3 + round(leg), 30))
	if inventory.size() != target_size:
		inventory.resize(target_size)
		emit_signal("inventory_updated")

func add_item(item: ItemData, amount: int = 1) -> int:
	var remaining = amount
	
	# 1. Stack into existing slots
	if item.max_stack > 1:
		for i in range(inventory.size()):
			var slot = inventory[i]
			if slot != null and slot["item"] == item:
				var space = item.max_stack - slot["count"]
				if space > 0:
					var to_add = min(space, remaining)
					# Check weight
					if get_total_weight() + (to_add * item.weight) > get_max_weight():
						var weight_room = get_max_weight() - get_total_weight()
						var weight_can_add = floor(weight_room / item.weight) if item.weight > 0 else to_add
						to_add = min(to_add, weight_can_add)
					
					if to_add > 0:
						slot["count"] += to_add
						remaining -= to_add
					
					if remaining == 0:
						emit_signal("inventory_updated")
						return 0

	# 2. Place into empty slots
	for i in range(inventory.size()):
		if remaining == 0: break
		if inventory[i] == null:
			var to_add = min(item.max_stack, remaining)
			
			# Check weight
			if get_total_weight() + (to_add * item.weight) > get_max_weight():
				var weight_room = get_max_weight() - get_total_weight()
				var weight_can_add = floor(weight_room / item.weight) if item.weight > 0 else to_add
				to_add = min(to_add, weight_can_add)
			
			if to_add > 0:
				inventory[i] = { "item": item, "count": to_add }
				remaining -= to_add
			else:
				break
				
	emit_signal("inventory_updated")
	return remaining

func remove_item(index: int, amount: int) -> void:
	if index < 0 or index >= inventory.size() or inventory[index] == null:
		return
	
	inventory[index]["count"] -= amount
	if inventory[index]["count"] <= 0:
		inventory[index] = null
	
	emit_signal("inventory_updated")

func get_total_weight() -> int:
	var w = 0
	# Inventory
	for slot in inventory:
		if slot != null:
			w += slot["item"].weight * slot["count"]
	# Equipment
	for key in equipment:
		var slot = equipment[key]
		if slot != null:
			w += slot["item"].weight * slot["count"]
	return w

func consume_equipment(key: String, amount: int) -> bool:
	var slot = equipment.get(key)
	if slot == null or slot["count"] < amount:
		return false
	
	slot["count"] -= amount
	if slot["count"] <= 0:
		_unequip_effect(slot["item"])
		equipment[key] = null
	
	emit_signal("inventory_updated")
	return true

func get_max_weight() -> int:
	return 500 + int(round(leg * 10))

# --- Item Usage / Equipment Logic ---

func use_item(index: int) -> void:
	if index < 0 or index >= inventory.size() or inventory[index] == null:
		return
	
	var item = inventory[index]["item"]
	
	if item.type == "food":
		get_tree().call_group("player", "hp_changed", item.strongness)
		remove_item(index, 1)
	
	elif item.type in ["helmet", "body", "weapon", "shield", "arrow"]:
		_equip_item(index)

func _equip_item(index: int) -> void:
	var slot = inventory[index]
	var item = slot["item"]
	var type = item.type
	
	var equip_key = ""
	if type in ["helmet", "body", "weapon"]:
		equip_key = type
	elif type in ["shield", "arrow"]:
		equip_key = "offhand"
	
	if equip_key == "": return
	
	# Check if already equipped
	if equipment[equip_key] != null:
		var old_entry = equipment[equip_key]
		# Unequip old first
		_unequip_effect(old_entry["item"])
		
		# Try to add old to inventory
		var leftover = add_item(old_entry["item"], old_entry["count"])
		if leftover > 0:
			# Inventory full, revert (this is tricky, maybe just drop?)
			print("Inventory full, dropping swapped item")
			# For now, let's just drop it or lose it? Or fail?
			# To be safe, let's just fail the equip if inventory is full?
			# But we are removing the item from inventory to equip, so there should be space?
			# Not necessarily if stacks differ.
			pass
	
	# Apply new equipment
	var count_to_equip = 1
	if type == "arrow":
		count_to_equip = slot["count"]
	
	equipment[equip_key] = { "item": item, "count": count_to_equip }
	_equip_effect(item)
	
	remove_item(index, count_to_equip)
	emit_signal("inventory_updated")

func unequip_item(equip_key: String) -> void:
	if equipment.get(equip_key) == null:
		return
		
	var entry = equipment[equip_key]
	var leftover = add_item(entry["item"], entry["count"])
	
	if leftover == 0:
		_unequip_effect(entry["item"])
		equipment[equip_key] = null
		emit_signal("inventory_updated")
	else:
		print("Inventory full, cannot unequip")
		# Handle partial unequip?

func _equip_effect(item: ItemData) -> void:
	match item.type:
		"helmet", "body":
			get_tree().call_group("player", "max_hp_changed", item.strongness)
		"weapon":
			get_tree().call_group("player", "change_weapon", item)

func _unequip_effect(item: ItemData) -> void:
	match item.type:
		"helmet", "body":
			get_tree().call_group("player", "max_hp_changed", -item.strongness)
		"weapon":
			get_tree().call_group("player", "clear_weapon")
