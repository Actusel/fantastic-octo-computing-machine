extends Node

const SAVE_PATH = "user://savegame.json"

func save_game():
	var save_data = {
		"level": Global.level,
		"graph_data": Global.graph_data,
		"inventory": _serialize_inventory(),
		"equipment": _serialize_equipment()
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data)
		file.store_string(json_string)
		print("Game saved to " + SAVE_PATH)
	else:
		print("Failed to open save file for writing")

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found")
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var save_data = json.get_data()
			
			# Unequip current items to reverse stats before loading new ones
			Global.unequip_all()
			
			_apply_save_data(save_data)
			
			# Re-apply effects of newly loaded equipment
			Global.reapply_equipment_effects()
			
			print("Game loaded")
		else:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())

func _serialize_inventory() -> Array:
	var serialized = []
	for slot in Global.inventory:
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
	for key in Global.equipment:
		var slot = Global.equipment[key]
		if slot == null:
			serialized[key] = null
		else:
			serialized[key] = {
				"path": slot["item"].resource_path,
				"count": slot["count"]
			}
	return serialized

func _apply_save_data(data: Dictionary):
	if "level" in data:
		Global.level = int(data["level"])
	
	if "graph_data" in data:
		Global.update(data["graph_data"])
	
	if "inventory" in data:
		var saved_inv = data["inventory"]
		# Ensure size matches saved data if it's larger (to avoid index out of bounds)
		if saved_inv.size() > Global.inventory.size():
			Global.inventory.resize(saved_inv.size())
			
		for i in range(saved_inv.size()):
			var slot_data = saved_inv[i]
			if slot_data:
				var item = load(slot_data["path"])
				if item:
					Global.inventory[i] = { "item": item, "count": int(slot_data["count"]) }
				else:
					Global.inventory[i] = null
			else:
				Global.inventory[i] = null
		
		# Clear any remaining slots if inventory is larger than saved
		for i in range(saved_inv.size(), Global.inventory.size()):
			Global.inventory[i] = null
				
	if "equipment" in data:
		var saved_eq = data["equipment"]
		for key in saved_eq:
			if key in Global.equipment:
				var slot_data = saved_eq[key]
				if slot_data:
					var item = load(slot_data["path"])
					if item:
						Global.equipment[key] = { "item": item, "count": int(slot_data["count"]) }
					else:
						Global.equipment[key] = null
				else:
					Global.equipment[key] = null

	Global.emit_signal("inventory_updated")
