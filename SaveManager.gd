extends Node

signal game_saved

const SAVE_PATH = "user://savegame.json"

func save_game():
	var save_data = Global.get_save_data()
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data)
		file.store_string(json_string)
		print("Game saved to " + SAVE_PATH)
		emit_signal("game_saved")
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
			Global.load_save_data(save_data)
			print("Game loaded")
		else:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
