class_name BaseEntity extends CharacterBody2D

signal health_changed(new_value, max_value)
signal died

@export var max_hp: float = 100.0
@export var speed: float = 100.0

var current_hp: float
var can_attack: bool = true

# Optional references - children classes should assign these if they exist
var hp_bar: ProgressBar

func _ready() -> void:
	current_hp = max_hp
	if has_node("ui/HP"): # Player structure
		hp_bar = $ui/HP
	elif has_node("hp_bar"): # Enemy structure
		hp_bar = $hp_bar
		
	update_health_ui()

func take_damage(amount: float):
	current_hp -= amount
	current_hp = clamp(current_hp, 0, max_hp)
	
	emit_signal("health_changed", current_hp, max_hp)
	update_health_ui()
	
	if current_hp <= 0:
		die()

func heal(amount: float):
	current_hp += amount
	current_hp = clamp(current_hp, 0, max_hp)
	
	emit_signal("health_changed", current_hp, max_hp)
	update_health_ui()

func update_health_ui():
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp

func die():
	emit_signal("died")
	# Override in children
