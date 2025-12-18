class_name LootItem extends Resource

enum Distribution {
	UNIFORM,
	LOWER_IS_BETTER
}

@export var item_data: ItemData
@export_range(0.0, 1.0) var chance: float = 1.0
@export var min_amount: int = 1
@export var max_amount: int = 1
@export var distribution: Distribution = Distribution.UNIFORM

func get_drop_count() -> int:
	if min_amount >= max_amount:
		return min_amount
		
	match distribution:
		Distribution.UNIFORM:
			return randi_range(min_amount, max_amount)
		Distribution.LOWER_IS_BETTER:
			# Bias towards min_amount using a square curve
			var t = randf()
			t = t * t
			return min_amount + floor(t * (max_amount - min_amount + 1))
	
	return min_amount
