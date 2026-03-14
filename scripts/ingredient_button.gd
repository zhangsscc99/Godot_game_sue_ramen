extends TextureButton

# 食材按钮：按下即开始拖拽
@export var ingredient_id: String = "water"
@export var icon_texture: Texture2D

func _ready() -> void:
	button_down.connect(_on_button_down)

func _on_button_down() -> void:
	var game: Node = get_tree().get_first_node_in_group("game")
	if game and icon_texture:
		game.call("start_drag", ingredient_id, icon_texture)
