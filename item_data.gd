# res://scripts/item_data.gd
extends Resource
class_name ItemData

# Item types inside the resource so other scripts can reference ItemData.TypeList


@export var item_name: String = "New Item"
# Export a typed enum property. This shows a dropdown in the inspector.
@export_enum("helmet", "body", "food", "weapon", "shield") var type: String = "food"

@export_enum("short","long") var weapon_range: String = "short"
@export var projectile_scene: PackedScene

@export var icon: Texture2D
@export var weight: int = 0
@export var strongness: float = 0.0

# Optional: you can add more fields later (description, durability, stack_size, effect_script, etc.)
