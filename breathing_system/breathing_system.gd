class_name BreathingSystem
extends PanelContainer

enum Result { PERFECT, GOOD, MISS }

signal oxygen_changed(value: float)
signal oxygen_depleted
signal breath_result(result: Result)
signal choke_started
signal choke_resolved(success: bool)

@export_group("Oxygen")
@export var max_oxygen: float = 100.0
@export var starting_oxygen: float = 100.0
@export var drain_per_second: float = 3.0

@export_group("Rhythm")
@export var circle_cycle_seconds: float = 2.4
@export_range(0.0, 1.0, 0.01) var min_circle_ratio: float = 0.3
@export_range(0.0, 1.0, 0.01) var target_circle_ratio: float = 0.85
@export var perfect_window_seconds: float = 0.06
@export var good_window_seconds: float = 0.18
@export var press_cooldown_seconds: float = 0.25

@export_group("Refill")
@export var perfect_refill: float = 25.0
@export var good_refill: float = 12.0
@export var miss_penalty: float = 8.0

@export_group("Choking")
@export var choke_enabled: bool = true
@export var choke_interval_seconds: float = 12.0
@export var choke_interval_jitter: float = 4.0
@export var choke_oxygen_loss: float = 20.0
@export var choke_window_seconds: float = 2.5
@export var choke_gasp_refill: float = 10.0
@export var choke_fail_penalty: float = 8.0

@export_group("Input")
@export var breath_key: Key = KEY_SPACE

@export_group("Startup")
@export var auto_start: bool = true

var oxygen: float = 0.0
var drain_multiplier: float = 1.0
var running: bool = false

var _phase: float = 0.0
var _choke_active: bool = false
var _choke_time_left: float = 0.0
var _next_choke_in: float = 0.0
var _press_cooldown_left: float = 0.0
var _depleted: bool = false
var _fill_style: StyleBoxFlat

@onready var _oxygen_bar: ProgressBar = %OxygenBar
@onready var _oxygen_value: Label = %OxygenValue
@onready var _circle: Control = %RhythmCircle
@onready var _result_label: Label = %ResultLabel
@onready var _choke_label: Label = %ChokeLabel
@onready var _hint_label: Label = %HintLabel


func _ready() -> void:
	max_oxygen = maxf(max_oxygen, 1.0)
	starting_oxygen = clampf(starting_oxygen, 0.0, max_oxygen)
	oxygen = starting_oxygen
	_oxygen_bar.max_value = max_oxygen

	var fill := _oxygen_bar.get_theme_stylebox("fill")
	if fill is StyleBoxFlat:
		_fill_style = fill.duplicate()
		_oxygen_bar.add_theme_stylebox_override("fill", _fill_style)

	set_process(false)
	_reset_visuals()
	if auto_start:
		start.call_deferred()
	else:
		_circle.visible = false
		_hint_label.text = "Call start() to begin"


func start() -> void:
	if running:
		return
	if oxygen <= 0.0:
		_deplete()
		return

	_depleted = false
	running = true
	set_process(true)
	_choke_active = false
	_press_cooldown_left = 0.0
	_schedule_next_choke()
	_circle.visible = true
	_choke_label.text = ""
	_hint_label.text = "Press SPACE when the circle touches the ring"
	_update_circle()


func stop() -> void:
	if _depleted:
		return
	running = false
	set_process(false)
	_choke_active = false
	_circle.visible = false
	_choke_label.text = ""
	_hint_label.text = "Paused"


func reset() -> void:
	running = false
	set_process(false)
	_depleted = false
	_choke_active = false
	_choke_time_left = 0.0
	_next_choke_in = 0.0
	_press_cooldown_left = 0.0
	_phase = 0.0
	drain_multiplier = 1.0
	oxygen = clampf(starting_oxygen, 0.0, max_oxygen)
	_reset_visuals()
	oxygen_changed.emit(oxygen)
	start()


func set_drain_multiplier(multiplier: float) -> void:
	drain_multiplier = maxf(multiplier, 0.0)


func trigger_choke() -> void:
	if not running or _choke_active or _depleted:
		return
	_begin_choke()


func _process(delta: float) -> void:
	if not running:
		return

	if _press_cooldown_left > 0.0:
		_press_cooldown_left = maxf(0.0, _press_cooldown_left - delta)

	if _choke_active:
		_choke_time_left -= delta
		if _choke_time_left <= 0.0:
			_finish_choke(false)
		return

	_drain_oxygen(delta)
	if not running:
		return

	_phase = fposmod(_phase + delta / maxf(circle_cycle_seconds, 0.1), 1.0)
	_update_circle()

	if choke_enabled:
		_next_choke_in -= delta
		if _next_choke_in <= 0.0:
			_begin_choke()


func _unhandled_key_input(event: InputEvent) -> void:
	if not running:
		return

	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode != breath_key:
		return

	get_viewport().set_input_as_handled()
	if _choke_active:
		_finish_choke(true)
	else:
		_attempt_breath()


func _drain_oxygen(delta: float) -> void:
	oxygen = maxf(0.0, oxygen - drain_per_second * drain_multiplier * delta)
	_update_oxygen_ui()
	oxygen_changed.emit(oxygen)
	if oxygen <= 0.0:
		_deplete()


func _attempt_breath() -> void:
	if not running or _choke_active or _depleted:
		return
	if _press_cooldown_left > 0.0:
		return

	_press_cooldown_left = maxf(press_cooldown_seconds, 0.0)
	var speed := maxf(_radius_speed(), 0.001)
	var error_seconds := absf(_current_radius_ratio() - _clamped_target()) / speed

	var result: Result
	if error_seconds <= perfect_window_seconds:
		result = Result.PERFECT
	elif error_seconds <= good_window_seconds:
		result = Result.GOOD
	else:
		result = Result.MISS

	_apply_result(result)


func _apply_result(result: Result) -> void:
	match result:
		Result.PERFECT:
			oxygen = minf(max_oxygen, oxygen + perfect_refill)
			_result_label.text = "Perfect  +%d" % roundi(perfect_refill)
			_result_label.add_theme_color_override("font_color", Color("#34d399"))
		Result.GOOD:
			oxygen = minf(max_oxygen, oxygen + good_refill)
			_result_label.text = "Good  +%d" % roundi(good_refill)
			_result_label.add_theme_color_override("font_color", Color("#fbbf24"))
		Result.MISS:
			oxygen = maxf(0.0, oxygen - miss_penalty)
			_result_label.text = "Miss" if miss_penalty <= 0.0 else "Miss  -%d" % roundi(miss_penalty)
			_result_label.add_theme_color_override("font_color", Color("#f87171"))

	_update_oxygen_ui()
	oxygen_changed.emit(oxygen)
	breath_result.emit(result)

	if oxygen <= 0.0:
		_deplete()


func _begin_choke() -> void:
	if not running or _choke_active or _depleted:
		return

	_choke_active = true
	_choke_time_left = maxf(choke_window_seconds, 0.1)
	oxygen = maxf(0.0, oxygen - choke_oxygen_loss)
	_update_oxygen_ui()
	oxygen_changed.emit(oxygen)
	choke_started.emit()
	_circle.visible = false
	_choke_label.text = "CHOKING! Press SPACE"
	_choke_label.add_theme_color_override("font_color", Color("#f87171"))
	_hint_label.text = "Gasp within %.1f seconds" % _choke_time_left

	if oxygen <= 0.0:
		_deplete()


func _finish_choke(success: bool) -> void:
	if not _choke_active:
		return

	_choke_active = false
	if success:
		oxygen = minf(max_oxygen, oxygen + choke_gasp_refill)
		_choke_label.text = "GASP!  +%d oxygen" % roundi(choke_gasp_refill)
		_choke_label.add_theme_color_override("font_color", Color("#34d399"))
	else:
		oxygen = maxf(0.0, oxygen - choke_fail_penalty)
		_choke_label.text = "CHOKE FAILED  -%d" % roundi(choke_fail_penalty)
		_choke_label.add_theme_color_override("font_color", Color("#f87171"))

	_update_oxygen_ui()
	oxygen_changed.emit(oxygen)
	choke_resolved.emit(success)
	_circle.visible = true
	_hint_label.text = "Press SPACE when the circle touches the ring"

	if oxygen <= 0.0:
		_deplete()
		return

	_schedule_next_choke()
	_update_circle()


func _deplete() -> void:
	if _depleted:
		return

	_depleted = true
	running = false
	oxygen = 0.0
	set_process(false)
	_choke_active = false
	_circle.visible = false
	_choke_label.text = ""
	_result_label.text = "OUT OF OXYGEN"
	_result_label.add_theme_color_override("font_color", Color("#f87171"))
	_hint_label.text = "reset() to breathe again"
	_update_oxygen_ui()
	oxygen_depleted.emit()


func _schedule_next_choke() -> void:
	if not choke_enabled:
		_next_choke_in = INF
		return

	var base := maxf(choke_interval_seconds, 1.0)
	var jitter := clampf(choke_interval_jitter, 0.0, base)
	_next_choke_in = randf_range(maxf(base - jitter, 1.0), base + jitter)


func _update_circle() -> void:
	var speed := _radius_speed()
	_circle.set_state(
		_current_radius_ratio(),
		_clamped_target(),
		perfect_window_seconds * speed,
		good_window_seconds * speed
	)


func _current_radius_ratio() -> float:
	var wave := 1.0 - absf(_phase * 2.0 - 1.0)
	return lerpf(clampf(min_circle_ratio, 0.0, 1.0), 1.0, wave)


func _clamped_target() -> float:
	return clampf(target_circle_ratio, clampf(min_circle_ratio, 0.0, 1.0), 1.0)


func _radius_speed() -> float:
	var min_ratio := clampf(min_circle_ratio, 0.0, 1.0)
	return (1.0 - min_ratio) / maxf(circle_cycle_seconds * 0.5, 0.05)


func _update_oxygen_ui() -> void:
	var max_o := maxf(max_oxygen, 1.0)
	_oxygen_bar.max_value = max_o
	_oxygen_bar.value = oxygen
	_oxygen_value.text = str(roundi(oxygen))

	if _fill_style == null:
		return

	var ratio := clampf(oxygen / max_o, 0.0, 1.0)
	if ratio > 0.5:
		_fill_style.bg_color = Color("#34d399")
	elif ratio > 0.25:
		_fill_style.bg_color = Color("#fbbf24")
	else:
		_fill_style.bg_color = Color("#f87171")


func _reset_visuals() -> void:
	_result_label.text = "—"
	_result_label.add_theme_color_override("font_color", Color(0.72, 0.80, 0.84))
	_choke_label.text = ""
	_hint_label.text = "Press SPACE when the circle touches the ring"
	_circle.visible = true
	_update_oxygen_ui()
	_update_circle()
