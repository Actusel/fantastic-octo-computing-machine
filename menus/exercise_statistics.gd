extends Control

@onready var year = $VBoxContainer/DateRow/year
@onready var month = $VBoxContainer/DateRow/month
@onready var day = $VBoxContainer/DateRow/day
@onready var weight = $VBoxContainer/WeightRow/weight
@onready var submit = $VBoxContainer/ButtonsRow/submit
@onready var clear = $VBoxContainer/ButtonsRow/clear
@onready var option_button: OptionButton = $VBoxContainer/HBoxContainer/exercises
@onready var add_graph: Button = $VBoxContainer/HBoxContainer/add_graph
@onready var line_edit: LineEdit = $VBoxContainer/HBoxContainer/new_graph
@onready var graph_ = $"graph_"
@onready var label: Label = $VBoxContainer/WeightRow/label
@onready var save_to_file: Button = $VBoxContainer/FileSaveRow/SaveToFile

var graph_data := {} 
var current_graph = "Squat" # Default
var reps_input: SpinBox

# Called when the node enters the scene tree for the first time.
func _ready():
	# Dynamic UI for Reps
	var weight_row = $VBoxContainer/WeightRow
	var reps_label = Label.new()
	reps_label.text = "Reps/Km:"
	weight_row.add_child(reps_label)
	
	reps_input = SpinBox.new()
	reps_input.min_value = 1
	reps_input.max_value = 9999
	reps_input.value = 5
	weight_row.add_child(reps_input)

	var current_time = Time.get_datetime_dict_from_system()
	year.value = current_time["year"]
	month.select(current_time["month"] - 1)
	day.value = current_time["day"]
	SaveManager.load_game()
	Global.game_started.connect(_on_game_started)
	
	graph_data = Global.graph_data
	
	option_button.clear()
	# Add DB exercises first
	for ex in Global.exercise_db.keys():
		option_button.add_item(ex)
		if not graph_data.has(ex):
			graph_data[ex] = []
			
	# Add any extra legacy keys
	for key in graph_data.keys():
		if not Global.exercise_db.has(key):
			option_button.add_item(key)
			
	option_button.item_selected.connect(_on_graph_selected)
	submit.pressed.connect(_on_submit)
	clear.pressed.connect(_on_clear)
	save_to_file.pressed.connect(_on_save_button_pressed)
	add_graph.pressed.connect(_on_add_graph)
	
	_update_stats_label()
	
	if graph_.all_graphs:graph_.update_graph(graph_data)
	else: 
		# Safe default if current_graph is invalid
		if not graph_data.has(current_graph):
			current_graph = option_button.get_item_text(0)
		graph_.update_graph(graph_data.get(current_graph, []))

func _on_add_graph():
	if not line_edit.text: return
	var graph_name = line_edit.text
	option_button.add_item(graph_name)
	graph_data[graph_name] = []
	line_edit.text = ""

func _on_graph_selected(index: int) -> void:
	current_graph = option_button.get_item_text(index)
	if not graph_.all_graphs: graph_.update_graph(graph_data.get(current_graph, []))
	_update_stats_label()
	
	# Update Input Labels based on type
	var type = Global.exercise_db.get(current_graph, "")
	if type == "cardio":
		label.text = "Distance (km):"
		# Optional: Hint that Reps is ignored or used for Time
	else:
		label.text = "Weight (kg):"

func _update_stats_label():
	var type = Global.exercise_db.get(current_graph, "unknown")
	var level = 0.0
	if type == "upper_body": level = Global.arm
	elif type == "lower_body": level = Global.leg
	elif type == "cardio": level = Global.stamina
	
	if type != "unknown":
		label.text = "Lvl " + str(snapped(level, 0.1)) + " (" + type + ")"
	else:
		label.text = "Weight(kg):"


func _on_submit():
	var y_val = weight.value # Weight / Distance
	var r_val = reps_input.value # Reps / Time(min)?
	
	var datetime = {
		"year": int(year.value),
		"month": month.get_selected_id() + 1,
		"day": int(day.value)
	}
	var unix_time = Time.get_unix_time_from_datetime_dict(datetime)
	
	# Pass to Global for scoring and pool update
	Global.log_exercise(current_graph, y_val, r_val, unix_time)
	
	# Current UI Graph update (Local mimic)
	# Find if date exists to overwrite for graph visualization
	var series = graph_data[current_graph]
	var updated = false
	for points in series:
		if points["date"] == unix_time:
			points["y"] = y_val
			updated = true
			break
	if not updated: series.append({ "date": unix_time, "y": y_val })
	
	if graph_.all_graphs: graph_.call_deferred("update_graph", graph_data)
	else: graph_.call_deferred("update_graph", graph_data[current_graph])
	
	_update_stats_label()

func _on_game_started():
	Global.update_graph_data(graph_data)

func _on_clear():
	# This clears GRAPH history, but maybe not Pools?
	# For safety, let's just clear graph data. Pools accumulate.
	graph_data = {}
	graph_.update_graph(graph_data)


func _on_save_button_pressed():
	Global.update_graph_data(graph_data)
	SaveManager.save_game()
