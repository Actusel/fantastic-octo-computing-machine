extends Control

@onready var year = $VBoxContainer/DateRow/year
@onready var month = $VBoxContainer/DateRow/month
@onready var day = $VBoxContainer/DateRow/day
@onready var weight = $VBoxContainer/WeightRow/weight
@onready var submit = $VBoxContainer/ButtonsRow/submit
@onready var clear = $VBoxContainer/ButtonsRow/clear


@onready var graph_ = $"graph?"



# Called when the node enters the scene tree for the first time.
func _ready():
	submit.pressed.connect(_on_submit)
	clear.pressed.connect(_on_clear)

func _on_submit():
	pass
	
func _on_clear():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
