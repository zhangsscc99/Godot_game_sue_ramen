extends Node2D

# ── 游戏主控制器 ───────────────────────────────────────
const GAME_TIME    := 90.0
const PENALTY      := 500

@onready var time_label:   Label = $UI/TimeLabel
@onready var score_label:  Label = $UI/ScoreLabel
@onready var combo_label:  Label = $UI/ComboLabel
@onready var msg_label:    Label = $UI/MsgLabel
@onready var pots_container: Node2D = $Pots

var time_left:  float = GAME_TIME
var score:      int   = 0
var combo:      int   = 0
var game_over:  bool  = false

# 拖拽状态
var dragging_ingredient: String = ""
var drag_icon: Sprite2D = null

func _ready() -> void:
	# 连接所有锅的信号
	for pot in pots_container.get_children():
		pot.pot_done.connect(_on_pot_done)
		pot.pot_burnt.connect(_on_pot_burnt)

func _process(delta: float) -> void:
	if game_over:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_end_game()

	time_label.text = "%d" % int(time_left)

	# 颜色警告
	if time_left < 15.0:
		time_label.modulate = Color(1.0, 0.2, 0.2)
	elif time_left < 30.0:
		time_label.modulate = Color(1.0, 0.8, 0.0)
	else:
		time_label.modulate = Color.WHITE

	# 拖拽图标跟随鼠标
	if drag_icon:
		drag_icon.global_position = get_global_mouse_position()

# ── 拖拽系统 ──────────────────────────────────────────
func start_drag(ingredient: String, icon_texture: Texture2D) -> void:
	if dragging_ingredient != "":
		return
	dragging_ingredient = ingredient
	drag_icon = Sprite2D.new()
	drag_icon.texture = icon_texture
	var tex_size: Vector2 = icon_texture.get_size()
	var max_size: float = 80.0
	var scale_factor: float = min(max_size / tex_size.x, max_size / tex_size.y)
	drag_icon.scale = Vector2(scale_factor, scale_factor)
	drag_icon.z_index = 100
	add_child(drag_icon)
	drag_icon.global_position = get_global_mouse_position()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragging_ingredient != "":
			_try_drop_on_pot()

func _try_drop_on_pot() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	for pot: Node2D in pots_container.get_children():
		var pot_rect := Rect2(pot.global_position - Vector2(80, 60), Vector2(160, 120))
		if pot_rect.has_point(mouse_pos):
			var accepted: bool = pot.call("add_ingredient", dragging_ingredient)
			if accepted:
				_show_msg("+食材：" + _ingredient_name(dragging_ingredient))
			break
	_end_drag()

func _end_drag() -> void:
	dragging_ingredient = ""
	if drag_icon:
		drag_icon.queue_free()
		drag_icon = null

# ── 锅信号处理 ────────────────────────────────────────
func _on_pot_done(pot: Node2D, pts: int) -> void:
	combo += 1
	var total := pts + (combo - 1) * 100
	score += total
	score_label.text = "%d" % score
	combo_label.text = "连击 x%d" % combo if combo > 1 else ""
	_show_msg("完成！+%d 分" % total, Color(0.2, 0.9, 0.3))

func _on_pot_burnt(_pot: Node2D) -> void:
	combo = 0
	score = max(0, score - PENALTY)
	score_label.text = "%d" % score
	combo_label.text = ""
	_show_msg("烧糊了！-%d 分" % PENALTY, Color(1.0, 0.3, 0.1))

# ── 工具 ──────────────────────────────────────────────
func _show_msg(text: String, color: Color = Color.WHITE) -> void:
	msg_label.text = text
	msg_label.modulate = color
	msg_label.modulate.a = 1.0
	# 淡出
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(msg_label, "modulate:a", 0.0, 0.6)

func _ingredient_name(id: String) -> String:
	match id:
		"water":     return "水"
		"ramen":     return "面"
		"seasoning": return "调料"
		"egg":       return "鸡蛋"
		"onion":     return "葱"
		"leek":      return "葱"
		"bok_choy":  return "青菜"
		"serve":     return "完成"
	return id

func _end_game() -> void:
	game_over = true
	GameData.final_score = score
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")
