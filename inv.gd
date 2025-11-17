extends Control


@onready var inv_grid: GridContainer = $CenterContainer/GridContainer
@onready var hp_bar: ProgressBar = $"../HP"
@onready var label: Label = $weight
const INV_SLOT = preload("uid://bgstnt0syqkyr")

var total_slots: int = 3
var available_slots: int = 0
var next_available_slot
var total_weight = 0
var max_weight = 50

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_stats()
	for slots in total_slots:
		inv_grid.add_child(INV_SLOT.instantiate())
	update_inv()
	label.text = "carrying " + str(total_weight) + "/" + str(max_weight) + "kg"

func _update_stats(): 
	total_slots = 3 + round(Global.leg)
	max_weight = 500 + round(10*Global.leg)
	if total_slots>30:
		total_slots=30

func update_inv(nw = total_weight):
	total_weight = 0
	available_slots = 0
	var found_first = false
	for child in inv_grid.get_child_count():
		if not inv_grid.get_child(child).filled:
			available_slots+=1
			if not found_first: 
				next_available_slot = child
				found_first = true
	if not total_weight==nw:
		total_weight=nw
		label.text = "carrying " + str(total_weight) + "/" + str(max_weight) + "kg"
	if not found_first:
		next_available_slot=null
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_home"):
		toggle_inv()
		print(next_available_slot)
		print(available_slots)

func eat(hp: float):
	hp_bar.value+=hp

func toggle_inv():
	if visible:
		visible=false
	else:
		visible=true

func drop_from_inventory(_item): pass

func add_to_inventory(item):
	var weight = item.weight
	var new_weight = total_weight+weight
	#update slot
	if not next_available_slot==null and new_weight<max_weight: 
		var item_texture = item.get_child(0).texture
		var item_type = item.item_type
		inv_grid.get_child(next_available_slot).fill_slot(item_texture, weight, item_type)
		update_inv(new_weight)
