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
var current_graph = "leggies"

# Called when the node enters the scene tree for the first time.
func _ready():
	var current_time = Time.get_datetime_dict_from_system()
	year.value = current_time["year"]
	month.select(current_time["month"] - 1)
	day.value = current_time["day"]
	SaveManager.load_game()
	Global.game_started.connect(_on_game_started)
	if Global.graph_data: graph_data=Global.graph_data
	else: graph_data = {"leggies": [], "armstrong": [], "stamina": []}
	for keys in graph_data.keys():
		option_button.add_item(keys)
	option_button.item_selected.connect(_on_graph_selected)
	submit.pressed.connect(_on_submit)
	clear.pressed.connect(_on_clear)
	save_to_file.pressed.connect(_on_save_button_pressed)
	add_graph.pressed.connect(_on_add_graph)
	if graph_.all_graphs:graph_.update_graph(graph_data)
	else: graph_.update_graph(graph_data[current_graph])

func _on_add_graph():
	if not line_edit.text: return
	var graph_name = line_edit.text
	option_button.add_item(graph_name)
	graph_data[graph_name] = []
	line_edit.text = ""

func _on_graph_selected(index: int) -> void:
	current_graph = option_button.get_item_text(index)
	if not graph_.all_graphs: graph_.update_graph(graph_data[current_graph])
	
	if current_graph=="stamina": label.text = "VO2 max"
	else: label.text = "Weight(kg):"




func _on_submit():
	var y_val = weight.value
	var datetime = {
		"year": int(year.value),
		"month": month.get_selected_id() + 1,
		"day": int(day.value)
	}
	var unix_time = Time.get_unix_time_from_datetime_dict(datetime)
	var updated = false
	for points in graph_data[current_graph]:
		if points["date"] == unix_time:
			points["y"] = y_val
			updated = true
			break
	if not updated: graph_data[current_graph].append({ "date": unix_time, "y": y_val })
	
	if graph_.all_graphs: graph_.call_deferred("update_graph", graph_data)
	else: graph_.call_deferred("update_graph", graph_data[current_graph])

func _on_game_started():
	Global.update(graph_data)

func _on_clear():
	graph_data = {}
	graph_.update_graph(graph_data)

func _on_save_button_pressed():
	Global.update(graph_data)
	SaveManager.save_game()
