extends Control

@onready var back = $back
@onready var aim_assist_checkbox: CheckBox = $FlowContainer/AimAssist
@onready var save: Button = $Save
@onready var debug_toggle: CheckBox = $FlowContainer/DebugToggle

var aim_assist: bool
var debug_mode: bool

# Called when the node enters the scene tree for the first time.
func _ready():
	aim_assist = Global.aim_assist
	debug_mode = Global.debug_mode
	aim_assist_checkbox.button_pressed = aim_assist
	debug_toggle.button_pressed = debug_mode
	back.pressed.connect(menu)
	save.pressed.connect(save_game)
	aim_assist_checkbox.pressed.connect(func(pressed):
		aim_assist = pressed
		Global.aim_assist = aim_assist
	)
	debug_toggle.pressed.connect(func(pressed):
		debug_mode = pressed
		Global.debug_mode = debug_mode
	)
	
func menu():
	get_tree().change_scene_to_file("res://menus/main_menu.tscn")


func save_game():
	SaveManager.save_game()
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
