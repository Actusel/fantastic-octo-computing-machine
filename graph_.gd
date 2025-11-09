extends Control

var points: Array = []  # [{date: int (days since year 0), y: float}]

func update_graph(new_data: Array) -> void:
	points = new_data
	queue_redraw()

func _draw() -> void:
	if points.is_empty():
		return

	# Sort by date to keep the line ordered
	points.sort_custom(func(a, b): return a["date"] < b["date"])

	# Extract numeric x (days) and y values
	var x_values: Array = []
	var y_values: Array = []
	for p in points:
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

	# ---- Draw Data Points + Lines ----
	var prev_pos: Vector2
	for i in range(points.size()):
		var px = points[i]["date"]
		var py = points[i]["y"]
		var norm_x = (px - min_x) / (max_x - min_x)
		var norm_y = (py - min_y) / (max_y - min_y)
		var pos := Vector2(
			margin + norm_x * graph_width,
			origin.y - norm_y * graph_height
		)

		draw_circle(pos, 4, Color.SKY_BLUE)
		if i > 0:
			draw_line(prev_pos, pos, Color(0.2, 0.6, 1.0), 2)
		prev_pos = pos

	# ---- Draw Date Labels ----
	for i in range(points.size()):
		var px = points[i]["date"]
		var norm_x = (px - min_x) / (max_x - min_x)
		var pos_x = margin + norm_x * graph_width

		var date_label := days_to_date(points[i]["date"])
		var label_pos := Vector2(pos_x - 25, origin.y + 20)
		draw_string(
			get_theme_default_font(),
			label_pos,
			date_label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color.WHITE
		)

# ---- Helper: Convert day number -> YYYY-MM-DD ----
func days_to_date(total_days: float) -> String:
	var days = int(total_days)
	
	# Estimate year (approximation: 365.2425 days per year in Gregorian calendar)
	var year = int(days / 365.2425)
	
	# Refine year estimate by calculating actual days up to that year
	while true:
		var days_in_year = year * 365
		var leap_days = int(year / 4) - int(year / 100) + int(year / 400)
		var total_to_year = days_in_year + leap_days
		
		if total_to_year > days:
			year -= 1
		else:
			days -= total_to_year
			break
	
	# Check if current year is a leap year
	var is_leap = (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)
	
	# Days in each month
	var days_in_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if is_leap:
		days_in_month[1] = 29
	
	# Find the month
	var month = 1
	for m in range(12):
		if days > days_in_month[m]:
			days -= days_in_month[m]
			month += 1
		else:
			break
	
	# Remaining days is the day of month
	var day = days
	
	# Format as "year-month-day"
	return "%d-%02d-%02d" % [year, month, day]
