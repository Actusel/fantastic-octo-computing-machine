extends Control

@onready var play = $play
@onready var quit = $quit
@onready var options = $options
@onready var help: Button = $help
@onready var popup_panel: PopupPanel = $PopupPanel

# Called when the node enters the scene tree for the first time.
func _ready():
	play.pressed.connect(start_game)
	quit.pressed.connect(terminate)
	options.pressed.connect(nit_picky)
	help.pressed.connect(infor)
	popup_panel.size.x= get_viewport().size.x/3
	popup_panel.size.y= get_viewport().size.y/1.5
	popup_panel.popup_centered()
	popup_panel.visibility_changed.connect(_toggled)

func start_game():
	get_tree().change_scene_to_file("res://area_1.tscn")
	Global.emit_signal("game_started")
	

func infor():
	popup_panel.visible=true

func terminate():
	get_tree().quit()

func nit_picky():
	get_tree().change_scene_to_file("res://options.tscn")

func _toggled():
	if popup_panel.visible: help.disabled=true
	else: help.disabled=false
