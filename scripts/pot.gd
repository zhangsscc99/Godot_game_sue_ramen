extends Node2D

# ── 냄비 상태 머신 ──────────────────────────────────────
enum State {
	IDLE,
	HAS_WATER,
	BOILING,
	HAS_NOODLE,
	HAS_SEASONING,
	DONE,
	BURNT
}

const BOIL_TIME     := 4.0
const BURN_TIME     := 8.0
const DONE_TIMEOUT  := 6.0

var state: State = State.IDLE
var timer: float  = 0.0
var toppings: Array[String] = []

# 텍스처 (외부에서 주입)
@export var tex_empty:    Texture2D
@export var tex_boiling:  Texture2D
@export var tex_done:     Texture2D

@onready var pot_sprite:      Sprite2D     = $PotSprite
@onready var status_label:    Label        = $StatusLabel
@onready var progress_bar:    ProgressBar  = $ProgressBar
@onready var flame_sprite:    Sprite2D     = $FlameSprite
@onready var topping_display: HBoxContainer = $ToppingDisplay
@onready var highlight:       Panel        = $Highlight

signal state_changed(pot: Node2D, new_state: State)
signal pot_done(pot: Node2D, score: int)
signal pot_burnt(pot: Node2D)

func _ready() -> void:
	_refresh_visuals()

func _process(delta: float) -> void:
	match state:
		State.HAS_WATER:
			timer += delta
			progress_bar.value = timer / BOIL_TIME * 100.0
			if timer >= BOIL_TIME:
				_set_state(State.BOILING)
		State.BOILING, State.HAS_NOODLE, State.HAS_SEASONING:
			timer += delta
			progress_bar.value = (1.0 - timer / BURN_TIME) * 100.0
			if timer >= BURN_TIME:
				_burn()
		State.DONE:
			timer += delta
			progress_bar.value = (1.0 - timer / DONE_TIMEOUT) * 100.0
			if timer >= DONE_TIMEOUT:
				_burn()

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
		"egg", "onion", "leek", "bok_choy":
			if state == State.HAS_SEASONING:
				toppings.append(ingredient)
				_refresh_visuals()
				return true
		"serve":
			if state == State.HAS_SEASONING or state == State.DONE:
				_complete()
				return true
	return false

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
	await get_tree().create_timer(2.0).timeout
	_set_state(State.IDLE)
	toppings.clear()

func _calc_score() -> int:
	var base := 1000
	for _t in toppings:
		base += 200
	return base

func _refresh_visuals() -> void:
	if not is_inside_tree():
		return

	match state:
		State.IDLE:
			status_label.text = "빈냄비"
			status_label.modulate = Color(0.7, 0.4, 0.6, 1)
			flame_sprite.visible = false
			progress_bar.visible = false
			pot_sprite.modulate = Color.WHITE
			if tex_empty: pot_sprite.texture = tex_empty
		State.HAS_WATER:
			status_label.text = "끓는 중..."
			status_label.modulate = Color(0.3, 0.6, 1.0, 1)
			flame_sprite.visible = true
			progress_bar.visible = true
			progress_bar.modulate = Color(0.4, 0.8, 1.0)
			if tex_empty: pot_sprite.texture = tex_empty
		State.BOILING:
			status_label.text = "면 투입!"
			status_label.modulate = Color(1.0, 0.5, 0.0, 1)
			flame_sprite.visible = true
			progress_bar.visible = true
			progress_bar.modulate = Color(1.0, 0.4, 0.0)
			if tex_boiling: pot_sprite.texture = tex_boiling
		State.HAS_NOODLE:
			status_label.text = "양념 추가!"
			status_label.modulate = Color(1.0, 0.4, 0.0, 1)
			progress_bar.modulate = Color(1.0, 0.5, 0.0)
			if tex_boiling: pot_sprite.texture = tex_boiling
		State.HAS_SEASONING:
			status_label.text = "토핑/완성!"
			status_label.modulate = Color(0.1, 0.75, 0.2, 1)
			progress_bar.modulate = Color(0.2, 0.8, 0.2)
			if tex_done: pot_sprite.texture = tex_done
		State.DONE:
			status_label.text = "빨리 내봐!"
			status_label.modulate = Color(0.1, 0.75, 0.2, 1)
			if tex_done: pot_sprite.texture = tex_done
		State.BURNT:
			status_label.text = "탔어요!"
			status_label.modulate = Color(0.8, 0.1, 0.0, 1)
			pot_sprite.modulate = Color(0.5, 0.3, 0.1)
			progress_bar.visible = false
			flame_sprite.visible = false
			if tex_empty: pot_sprite.texture = tex_empty

	for child in topping_display.get_children():
		child.queue_free()
	for t in toppings:
		var lbl := Label.new()
		lbl.text = "🥚" if t == "egg" else "🌿"
		topping_display.add_child(lbl)

func set_highlighted(on: bool) -> void:
	highlight.visible = on
