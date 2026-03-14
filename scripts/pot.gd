extends Node2D

# ── 锅的状态机 ──────────────────────────────────────────
enum State {
	IDLE,          # 空锅等待
	HAS_WATER,     # 已加水，等待沸腾
	BOILING,       # 沸腾中，等待加面
	HAS_NOODLE,    # 已加面，等待调料
	HAS_SEASONING, # 已加调料，可选配料或直接完成
	DONE,          # 完成，等待端走
	BURNT          # 烧糊
}

const BOIL_TIME     := 4.0   # 加水后多久沸腾
const BURN_TIME     := 8.0   # 超时未处理就烧糊（从 BOILING 开始计）
const DONE_TIMEOUT  := 6.0   # 完成后多久没端走就烧糊

var state: State = State.IDLE
var timer: float  = 0.0
var toppings: Array[String] = []   # 已加的配料

# 节点引用（在 _ready 中获取）
@onready var pot_sprite:      Sprite2D  = $PotSprite
@onready var status_label:    Label     = $StatusLabel
@onready var progress_bar:    ProgressBar = $ProgressBar
@onready var flame_sprite:    Sprite2D  = $FlameSprite
@onready var topping_display: HBoxContainer = $ToppingDisplay
@onready var highlight:       Panel     = $Highlight

# 信号
signal state_changed(pot: Node2D, new_state: State)
signal pot_done(pot: Node2D, score: int)
signal pot_burnt(pot: Node2D)

# ── 生命周期 ───────────────────────────────────────────
func _ready() -> void:
	_refresh_visuals()

func _process(delta: float) -> void:
	match state:
		State.HAS_WATER:
			timer += delta
			progress_bar.value = timer / BOIL_TIME * 100.0
			if timer >= BOIL_TIME:
				_set_state(State.BOILING)

		State.BOILING:
			timer += delta
			progress_bar.value = (1.0 - timer / BURN_TIME) * 100.0
			if timer >= BURN_TIME:
				_burn()

		State.HAS_NOODLE, State.HAS_SEASONING:
			timer += delta
			progress_bar.value = (1.0 - timer / BURN_TIME) * 100.0
			if timer >= BURN_TIME:
				_burn()

		State.DONE:
			timer += delta
			progress_bar.value = (1.0 - timer / DONE_TIMEOUT) * 100.0
			if timer >= DONE_TIMEOUT:
				_burn()

# ── 外部调用：放入食材 ─────────────────────────────────
func add_ingredient(ingredient: String) -> bool:
	match ingredient:
		"water":
			if state == State.IDLE:
				_set_state(State.HAS_WATER)
				return true
		"ramen":
			if state == State.BOILING:
				_set_state(State.HAS_NOODLE)
				return true
		"seasoning":
			if state == State.HAS_NOODLE:
				_set_state(State.HAS_SEASONING)
				return true
		"egg", "leek", "bok_choy":
			if state == State.HAS_SEASONING:
				toppings.append(ingredient)
				_refresh_visuals()
				return true
		"serve":
			if state == State.HAS_SEASONING or state == State.DONE:
				_complete()
				return true
	return false   # 放入失败

# ── 内部状态切换 ───────────────────────────────────────
func _set_state(new_state: State) -> void:
	state = new_state
	timer = 0.0
	progress_bar.value = 0.0 if new_state == State.HAS_WATER else 100.0
	state_changed.emit(self, new_state)
	_refresh_visuals()

func _complete() -> void:
	var score := _calc_score()
	pot_done.emit(self, score)
	_set_state(State.IDLE)
	toppings.clear()

func _burn() -> void:
	_set_state(State.BURNT)
	pot_burnt.emit(self)
	# 自动 2 秒后重置
	await get_tree().create_timer(2.0).timeout
	_set_state(State.IDLE)
	toppings.clear()

# ── 计分 ──────────────────────────────────────────────
func _calc_score() -> int:
	var base := 1000
	for _t in toppings:
		base += 200
	return base

# ── 视觉刷新 ──────────────────────────────────────────
func _refresh_visuals() -> void:
	if not is_inside_tree():
		return

	match state:
		State.IDLE:
			status_label.text = "空锅"
			status_label.modulate = Color.WHITE
			flame_sprite.visible = false
			progress_bar.visible = false
			pot_sprite.modulate = Color.WHITE
		State.HAS_WATER:
			status_label.text = "等待沸腾..."
			flame_sprite.visible = true
			progress_bar.visible = true
			progress_bar.modulate = Color(0.4, 0.8, 1.0)
		State.BOILING:
			status_label.text = "沸腾！加面！"
			status_label.modulate = Color(1.0, 0.6, 0.0)
			flame_sprite.visible = true
			progress_bar.visible = true
			progress_bar.modulate = Color(1.0, 0.4, 0.0)
		State.HAS_NOODLE:
			status_label.text = "加调料！"
			progress_bar.modulate = Color(1.0, 0.6, 0.0)
		State.HAS_SEASONING:
			status_label.text = "可加配料或端走"
			status_label.modulate = Color(0.2, 0.8, 0.2)
			progress_bar.modulate = Color(0.2, 0.8, 0.2)
		State.DONE:
			status_label.text = "快端走！"
			progress_bar.modulate = Color(0.2, 0.8, 0.2)
		State.BURNT:
			status_label.text = "烧糊了！"
			status_label.modulate = Color(0.8, 0.2, 0.0)
			pot_sprite.modulate = Color(0.5, 0.3, 0.1)
			progress_bar.visible = false
			flame_sprite.visible = false

	# 更新配料显示
	for child in topping_display.get_children():
		child.queue_free()
	for t in toppings:
		var lbl := Label.new()
		lbl.text = "🥚" if t == "egg" else "🥬"
		topping_display.add_child(lbl)

# 鼠标悬停高亮
func set_highlighted(on: bool) -> void:
	highlight.visible = on
