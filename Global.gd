extends Node

signal game_started
signal inventory_updated

var level: int
var aim_assist = true
var debug_mode = false

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

var fitness_pools = {
	"upper_body": 0.0,
	"lower_body": 0.0,
	"cardio": 0.0, # Run/Cycle
	"last_decay_time": 0
}

var exercise_db = {
	# Lower Body
	"Squat": "lower_body",
	"Deadlift": "lower_body",
	"Lunge": "lower_body",
	"Leg Press": "lower_body",
	
	# Upper Body
	"Bench Press": "upper_body",
	"Overhead Press": "upper_body",
	"Push Up": "upper_body",
	"Pull Up": "upper_body",
	"Dumbbell Curl": "upper_body",
	"Rowing": "upper_body", 
	
	# Cardio
	"Running": "cardio",
	"Cycling": "cardio"
}

# Derived stats (Levels 0-100+)
# Example: 1250 pool -> Level 10-15?
# Let's say Level = Sqrt(Pool) / 2?  Sqrt(1250) = 35 / 2 = 17.
# Or just Pool / 100.
# 100kg * 5 reps = 100^1.2 * 5 = 251 * 5 = 1255.
# If we want Level ~12 for that, Pool/100 is good.
var leg: float:
	get: return fitness_pools["lower_body"] / 100.0
var arm: float:
	get: return fitness_pools["upper_body"] / 100.0
var stamina: float:
	get: return fitness_pools["cardio"] / 100.0
var back: float:
	get: return 0.0 # Merged into upper usually, or ignored

func update_graph_data(new_data):
	graph_data = new_data
	# Legacy max calculation removed in favor of fitness_pools
	_resize_inventory()

# New function to handle exercise logging
func log_exercise(exercise_name: String, weight: float, reps: float, date_unix: int):
	# 1. Update Graph History (Visuals)
	if not graph_data.has(exercise_name):
		graph_data[exercise_name] = []
	
	# Check if entry for date exists to overwrite?
	# For simplicity, just append. If we want overwrite logic, we can add it.
	# The UI currently does overwrite logic. We can keep UI logic and just sync here.
	# But accumulating pool is the key.
	
	# For accumulation: We add to the pool.
	# Formula: Score = (Weight ^ 1.2) * Reps
	# Weight in kg. Reps in count (or km for cardio).
	
	# Bias for cardio: "Weight" might be 1 (bodyweight) or speed?
	# Usually cardio is Distance (reps) * Speed?
	# Let's assume for Cardio: Weight input is Distance(km), Reps input is Time(min)? 
	# Or user just enters "reps" as distance?
	# Let's standardize: 
	# Lifting: Weight = kg, Reps = count.
	# Cardio: Weight = 0 (ignored) or 1? Reps = Distance(km)?
	
	var score = 0.0
	var type = exercise_db.get(exercise_name, "")
	
	if type == "cardio":
		# Cardio scoring: Distance * 100?
		# If user inputs Distance in "weight" box...
		# Assume 'weight' is the primary metric for the graph.
		# For running, usually graph is Pace or Distance.
		# Let's say Weight = Distance (km).
		score = weight * 50.0 # 5km run -> 250 points.
	else:
		# Lifting
		if weight <= 0: weight = 1.0 # Prevent error
		score = pow(weight, 1.2) * reps
	
	if type != "":
		fitness_pools[type] += score
		print("Added ", score, " to ", type, ". Total: ", fitness_pools[type])
	
	_resize_inventory()

func apply_decay():
	var current_time = Time.get_unix_time_from_system()
	if fitness_pools["last_decay_time"] == 0:
		fitness_pools["last_decay_time"] = current_time
		return

	var seconds_since = current_time - fitness_pools["last_decay_time"]
	var weeks = seconds_since / (60 * 60 * 24 * 7.0)
	
	if weeks >= 1.0:
		var decay_factor = pow(0.90, int(weeks)) # 10% per full week
		fitness_pools["upper_body"] *= decay_factor
		fitness_pools["lower_body"] *= decay_factor
		fitness_pools["cardio"] *= decay_factor
		
		# Advance time by the integer weeks processed
		fitness_pools["last_decay_time"] += int(weeks) * (60 * 60 * 24 * 7)
		print("Applied decay. Weeks: ", int(weeks), " Factor: ", decay_factor)
		_resize_inventory()


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
	return 100 + int(round(leg * 10))

# --- Item Usage / Equipment Logic ---

func use_item(index: int) -> void:
	if index < 0 or index >= inventory.size() or inventory[index] == null:
		return
	
	var item = inventory[index]["item"]
	
	if item.type == "food":
		get_tree().call_group("player", "heal", item.strongness)
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

func unequip_all() -> void:
	for key in equipment:
		if equipment[key] != null:
			_unequip_effect(equipment[key]["item"])
			equipment[key] = null
	emit_signal("inventory_updated")

func reapply_equipment_effects() -> void:
	for key in equipment:
		if equipment[key] != null:
			_equip_effect(equipment[key]["item"])


# --- Drag and Drop Helpers ---

func drag_move_inventory_to_inventory(from_idx: int, to_idx: int) -> void:
	if from_idx == to_idx: return
	var from_slot = inventory[from_idx]
	var to_slot = inventory[to_idx]
	
	if from_slot == null: return
	
	if to_slot == null:
		inventory[to_idx] = from_slot
		inventory[from_idx] = null
	elif to_slot["item"] == from_slot["item"] and to_slot["item"].max_stack > 1:
		var space = to_slot["item"].max_stack - to_slot["count"]
		var to_move = min(space, from_slot["count"])
		to_slot["count"] += to_move
		from_slot["count"] -= to_move
		if from_slot["count"] <= 0:
			inventory[from_idx] = null
	else:
		inventory[to_idx] = from_slot
		inventory[from_idx] = to_slot
	
	emit_signal("inventory_updated")

func drag_equip_to_inventory(equip_key: String, inv_idx: int) -> void:
	var equip_slot = equipment[equip_key]
	var inv_slot = inventory[inv_idx]
	
	if equip_slot == null: return
	
	if inv_slot == null:
		_unequip_effect(equip_slot["item"])
		inventory[inv_idx] = equip_slot
		equipment[equip_key] = null
	elif inv_slot["item"] == equip_slot["item"] and inv_slot["item"].max_stack > 1:
		var space = inv_slot["item"].max_stack - inv_slot["count"]
		var to_move = min(space, equip_slot["count"])
		inv_slot["count"] += to_move
		equip_slot["count"] -= to_move
		if equip_slot["count"] <= 0:
			_unequip_effect(equip_slot["item"])
			equipment[equip_key] = null
	else:
		# Swap check
		var item_to_equip = inv_slot["item"]
		var can_equip = false
		if equip_key == "helmet" and item_to_equip.type == "helmet": can_equip = true
		elif equip_key == "body" and item_to_equip.type == "body": can_equip = true
		elif equip_key == "weapon" and item_to_equip.type == "weapon": can_equip = true
		elif equip_key == "offhand" and (item_to_equip.type == "shield" or item_to_equip.type == "arrow"): can_equip = true
		
		if can_equip:
			_unequip_effect(equip_slot["item"])
			inventory[inv_idx] = equip_slot
			equipment[equip_key] = inv_slot
			_equip_effect(item_to_equip)
			
	emit_signal("inventory_updated")

func drag_inventory_to_equip(inv_idx: int, equip_key: String) -> void:
	var inv_slot = inventory[inv_idx]
	var equip_slot = equipment[equip_key]
	
	if inv_slot == null: return
	
	var item = inv_slot["item"]
	# Validation should happen before calling this, but double check
	var valid = false
	if equip_key == "helmet" and item.type == "helmet": valid = true
	elif equip_key == "body" and item.type == "body": valid = true
	elif equip_key == "weapon" and item.type == "weapon": valid = true
	elif equip_key == "offhand" and (item.type == "shield" or item.type == "arrow"): valid = true
	
	if not valid: return
	
	if equip_slot == null:
		equipment[equip_key] = inv_slot
		inventory[inv_idx] = null
		_equip_effect(item)
	else:
		_unequip_effect(equip_slot["item"])
		equipment[equip_key] = inv_slot
		inventory[inv_idx] = equip_slot
		_equip_effect(item)
		
	emit_signal("inventory_updated")


func move_inventory_item(from_index: int, to_index: int) -> void:
	if from_index == to_index: return
	if from_index < 0 or from_index >= inventory.size(): return
	if to_index < 0 or to_index >= inventory.size(): return
	
	var from_slot = inventory[from_index]
	var to_slot = inventory[to_index]
	
	if from_slot == null: return
	
	# If target is empty, just move
	if to_slot == null:
		inventory[to_index] = from_slot
		inventory[from_index] = null
	
	# If same item, try to stack
	elif to_slot["item"] == from_slot["item"] and to_slot["item"].max_stack > 1:
		var space = to_slot["item"].max_stack - to_slot["count"]
		var to_move = min(space, from_slot["count"])
		
		to_slot["count"] += to_move
		from_slot["count"] -= to_move
		
		if from_slot["count"] <= 0:
			inventory[from_index] = null
	
	# If different item, swap
	else:
		inventory[to_index] = from_slot
		inventory[from_index] = to_slot
	
	emit_signal("inventory_updated")

func unequip_into_slot(equip_key: String, target_inv_index: int) -> void:
	if equipment.get(equip_key) == null: return
	if target_inv_index < 0 or target_inv_index >= inventory.size(): return
	
	var equip_entry = equipment[equip_key]
	var target_slot = inventory[target_inv_index]
	
	# If target is empty, unequip there
	if target_slot == null:
		inventory[target_inv_index] = equip_entry
		equipment[equip_key] = null
		_unequip_effect(equip_entry["item"])
	
	# If target matches, stack
	elif target_slot["item"] == equip_entry["item"] and target_slot["item"].max_stack > 1:
		var space = target_slot["item"].max_stack - target_slot["count"]
		var to_move = min(space, equip_entry["count"])
		
		target_slot["count"] += to_move
		equip_entry["count"] -= to_move
		
		if equip_entry["count"] <= 0:
			equipment[equip_key] = null
			_unequip_effect(equip_entry["item"])
			
	# If target is different, try to swap (equip the target item)
	else:
		var new_item = target_slot["item"]
		var new_type = new_item.type
		
		# Check if the item in inventory can go to this equip slot
		var valid_key = ""
		if new_type in ["helmet", "body", "weapon"]:
			valid_key = new_type
		elif new_type in ["shield", "arrow"]:
			valid_key = "offhand"
			
		if valid_key == equip_key:
			# Perform swap
			_unequip_effect(equip_entry["item"])
			inventory[target_inv_index] = equip_entry
			
			equipment[equip_key] = target_slot
			_equip_effect(new_item)
	
	emit_signal("inventory_updated")



func get_save_data() -> Dictionary:
	return {
		"level": level,
		"graph_data": graph_data,
		"fitness_pools": fitness_pools,
		"inventory": _serialize_inventory(),
		"equipment": _serialize_equipment(),
		"options": {
			"aim_assist": aim_assist,
			"debug_mode": debug_mode
		}
	}

func load_save_data(data: Dictionary):
	unequip_all() # Reset stats
	
	if "level" in data:
		level = int(data["level"])
	
	if "graph_data" in data:
		graph_data = data["graph_data"]
		# Only update inventory, don't overwrite pools from graph
		_resize_inventory()
		
	if "fitness_pools" in data:
		fitness_pools = data["fitness_pools"]
		# Handle backward compatibility / initialization
		if not fitness_pools.has("last_decay_time"):
			fitness_pools["last_decay_time"] = Time.get_unix_time_from_system()
	else:
		# Initialize if new save
		fitness_pools["last_decay_time"] = Time.get_unix_time_from_system()
		
	apply_decay()

	if "inventory" in data:
		var saved_inv = data["inventory"]
		if saved_inv.size() > inventory.size():
			inventory.resize(saved_inv.size())
			
		for i in range(saved_inv.size()):
			var slot_data = saved_inv[i]
			if slot_data:
				var item = load(slot_data["path"])
				if item:
					inventory[i] = { "item": item, "count": int(slot_data["count"]) }
				else:
					inventory[i] = null
			else:
				inventory[i] = null
		
		for i in range(saved_inv.size(), inventory.size()):
			inventory[i] = null
				
	if "equipment" in data:
		var saved_eq = data["equipment"]
		for key in saved_eq:
			if key in equipment:
				var slot_data = saved_eq[key]
				if slot_data:
					var item = load(slot_data["path"])
					if item:
						equipment[key] = { "item": item, "count": int(slot_data["count"]) }
					else:
						equipment[key] = null
				else:
					equipment[key] = null

	reapply_equipment_effects()
	emit_signal("inventory_updated")

func _serialize_inventory() -> Array:
	var serialized = []
	for slot in inventory:
		if slot == null:
			serialized.append(null)
		else:
			serialized.append({
				"path": slot["item"].resource_path,
				"count": slot["count"]
			})
	return serialized

func _serialize_equipment() -> Dictionary:
	var serialized = {}
	for key in equipment:
		var slot = equipment[key]
		if slot == null:
			serialized[key] = null
		else:
			serialized[key] = {
				"path": slot["item"].resource_path,
				"count": slot["count"]
			}
	return serialized
