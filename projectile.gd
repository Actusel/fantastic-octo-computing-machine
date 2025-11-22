extends Area2D

@onready var visible_on_screen_notifier_2d: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

# Configurable properties for the projectile
@export var speed: float = 600.0
@export var damage: float = 10.0

# The direction the projectile will travel in (set by the enemy)
var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	visible_on_screen_notifier_2d.screen_exited.connect(_on_visible_on_screen_notifier_2d_screen_exited)

func _physics_process(delta: float) -> void:
	# Move the projectile in its set direction
	global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	# Check if the body we hit is the player
	if body.is_in_group("player"):
		Global.hp_changed.emit(-damage)

	# Destroy the projectile when it hits any physics body (player or wall)
	# We put it in the "projectile" group to avoid this.
	queue_free()


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	# Delete the projectile if it goes off-screen to save memory
	queue_free()
