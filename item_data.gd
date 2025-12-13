# res://scripts/item_data.gd
extends Resource
class_name ItemData

# Item types inside the resource so other scripts can reference ItemData.TypeList


@export var item_name: String = "New Item"
# Export a typed enum property. This shows a dropdown in the inspector.
@export_enum("helmet", "body", "food", "weapon", "shield", "arrow") var type: String = "food"


@export var icon: Texture2D
@export var weight: int = 0
@export var strongness: float = 0.0
@export var max_stack: int = 1   # food = 10, arrow = 10, others = 1

@export_category("weapon specific")
@export var attack_speed: float = 1
@export_enum("short","long") var weapon_range: String = "short"
@export var projectile_scene: PackedScene

# Optional: you can add more fields later (description, durability, stack_size, effect_script, etc.)
