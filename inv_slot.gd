extends Panel

@onready var item_display: Sprite2D = $item_display

func fill_slot(texture: Texture2D):
	item_display.texture = texture
	filled = true

var filled = false
