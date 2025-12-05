extends Node

signal game_started

var level = 1

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
	

func _find_max_y(series: Array) -> float:
	if series.is_empty():
		return 0.0
	var max_val = series[0]["y"]
	for p in series:
		if p["y"] > max_val:
			max_val = p["y"]
	return max_val
