extends Control

@onready var play = $play
@onready var quit = $quit
@onready var options = $options
@onready var help: Button = $help

# Called when the node enters the scene tree for the first time.
func _ready():
	play.pressed.connect(start_game)
	quit.pressed.connect(terminate)
	options.pressed.connect(nit_picky)
	help.pressed.connect(infor)
func start_game():
	get_tree().change_scene_to_file("res://area_1.tscn")
func infor():
	add_child(load("res://player.tscn").instantiate())
func terminate():
	get_tree().quit()
func nit_picky():
	get_tree().change_scene_to_file("res://options.tscn")
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
