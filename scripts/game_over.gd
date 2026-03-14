extends Node2D

@onready var final_score_label: Label = $ScoreLabel
@onready var rank_label: Label = $RankLabel

func _ready() -> void:
	var s: int = GameData.final_score if Engine.has_singleton("GameData") else 0
	final_score_label.text = str(s)
	rank_label.text = _get_rank(s)

func _get_rank(s: int) -> String:
	if s >= 15000: return "★★★ 泡面大师！"
	if s >= 10000: return "★★☆ 专业厨师"
	if s >= 5000:  return "★☆☆ 初级厨师"
	return "☆☆☆ 继续加油！"

func _on_retry_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
