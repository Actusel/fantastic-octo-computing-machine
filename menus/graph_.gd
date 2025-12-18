extends Control

var datasets = {}
var all_graphs = false
var colors = [Color.RED, Color.SKY_BLUE, Color.LIME_GREEN, Color.ORANGE, Color.VIOLET]

func update_graph(new_data) -> void:
	if typeof(new_data) == TYPE_DICTIONARY:
		datasets = new_data
	else:
		datasets = {"Single": new_data}
	queue_redraw()

func _draw() -> void:
	if datasets.is_empty():
		return

	# Sort by date to keep the line ordered
	var all_points: Array = []
	for series in datasets.values():
		all_points += series
	if all_points.is_empty():
		return

	# Extract numeric x (days) and y values
	var x_values: Array = []
	var y_values: Array = []
	for p in all_points:
		x_values.append(p["date"])
		y_values.append(p["y"])

	var min_x: float = x_values[0]
	var max_x: float = x_values[0]
	var min_y: float = y_values[0]
	var max_y: float = y_values[0]
	for x in x_values:
		if x < min_x: min_x = x
		if x > max_x: max_x = x
	for y in y_values:
		if y < min_y: min_y = y
		if y > max_y: max_y = y

	# Handle degenerate case
	if is_equal_approx(max_y, min_y):
		max_y += 1.0
	if is_equal_approx(max_x, min_x):
		max_x += 1.0

	var margin := 50.0
	var graph_width := size.x - margin * 2
	var graph_height := size.y - margin * 2

	# Axes
	var origin := Vector2(margin, size.y - margin)
	var x_axis_end := Vector2(size.x - margin, size.y - margin)
	var y_axis_end := Vector2(margin, margin)
	draw_line(origin, x_axis_end, Color(0.8, 0.8, 0.8), 2)
	draw_line(origin, y_axis_end, Color(0.8, 0.8, 0.8), 2)

	# ---- Draw Y-axis ticks ----
	var tick_count := 5
	for i in range(tick_count + 1):
		var t := float(i) / tick_count
		var y_val := lerpf(min_y, max_y, t)
		var y_pos := origin.y - graph_height * t
		draw_line(Vector2(margin - 5, y_pos), Vector2(margin + 5, y_pos), Color.GRAY)
		draw_string(
			get_theme_default_font(),
			Vector2(5, y_pos + 5),
			str(y_val),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color.WHITE
		)

# ---- Draw Date Labels ----

		
		

	# ---- Draw Data Points + Lines ----
	var color_index = 0
	for name in datasets.keys():
		var series = datasets[name]
		if series.is_empty():
			continue
		var color = colors[color_index % colors.size()]
		color_index += 1
		series.sort_custom(func(a,b): return a["date"] < b["date"])
		var prev_pos: Vector2
		for i in range(series.size()):
			var px = series[i]["date"]
			var py = series[i]["y"]
			var nx = (px - min_x) / (max_x - min_x)
			var ny = (py - min_y) / (max_y - min_y)
			var pos = Vector2(margin + nx * graph_width, origin.y - ny * graph_height)
			var date_label := Time.get_date_string_from_unix_time(int(px))
			var label_pos := Vector2(pos.x - 25, origin.y + 20)
			draw_string(
			get_theme_default_font(),
			label_pos,
			date_label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color.WHITE
		)
			draw_circle(pos, 4, color)
			if i > 0:
				draw_line(prev_pos, pos, color, 2)
			prev_pos = pos
