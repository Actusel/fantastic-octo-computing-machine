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
@onready var save_to_file: Button = $VBoxContainer/HBoxContainer2/SaveToFile

var graph_data := {} 
var current_graph := "leggies"

# Called when the node enters the scene tree for the first time.
func _ready():
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
	graph_.update_graph(graph_data)

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


func date_to_days(year: int, month: int, day: int) -> float:
	# Calculate days from complete years
	var total_days = year * 365
	
	# Add leap days (every 4 years, except century years unless divisible by 400)
	var leap_days = int(year / 4) - int(year / 100) + int(year / 400)
	total_days += leap_days
	
	# Days in each month (non-leap year)
	var days_in_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	
	# Check if current year is a leap year
	var is_leap = (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)
	if is_leap:
		days_in_month[1] = 29
	
	# Add days from complete months in current year
	for m in range(month):
		total_days += days_in_month[m]
	
	# Add remaining days
	total_days += day
	
	return float(total_days)

func _on_submit():
	var y_val = weight.value
	var days = date_to_days(year.value,(month.get_selected_id()),day.value)
	var updated = false
	for points in graph_data[current_graph]:
		if points["date"] == days:
			points["y"] = y_val
			updated = true
			break
	if not updated: graph_data[current_graph].append({ "date": days, "y": y_val })
	
	if graph_.all_graphs: graph_.call_deferred("update_graph", graph_data)
	else: graph_.call_deferred("update_graph", graph_data[current_graph])
	

func _on_game_started():
	Global.update(graph_data)

func _on_clear():
	pass

func _on_save_button_pressed():
	pass
