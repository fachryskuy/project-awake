extends Control

@export var track_color: Color = Color(1.0, 1.0, 1.0, 0.08)
@export var target_color: Color = Color("#fbbf24")
@export var moving_color: Color = Color("#5eead4")
@export var perfect_color: Color = Color("#34d399")
@export var good_color: Color = Color("#fbbf24")
@export var line_width: float = 4.0

var _radius_ratio: float = 0.3
var _target_ratio: float = 0.85
var _perfect_band: float = 0.0
var _good_band: float = 0.0


func _ready() -> void:
	resized.connect(queue_redraw)


func set_state(radius_ratio: float, target_ratio: float, perfect_band: float, good_band: float) -> void:
	_radius_ratio = clampf(radius_ratio, 0.0, 1.0)
	_target_ratio = clampf(target_ratio, 0.0, 1.0)
	_perfect_band = maxf(perfect_band, 0.0)
	_good_band = maxf(good_band, 0.0)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var max_radius := minf(size.x, size.y) * 0.5 - line_width * 2.0
	if max_radius <= 0.0:
		return

	var target_radius := _target_ratio * max_radius
	var moving_radius := _radius_ratio * max_radius

	draw_arc(center, max_radius, 0.0, TAU, 96, track_color, 1.0, true)

	if _good_band > 0.0:
		var good_width := minf(_good_band * max_radius * 2.0, max_radius * 0.6)
		draw_arc(center, target_radius, 0.0, TAU, 96, _with_alpha(good_color, 0.12), good_width, true)

	if _perfect_band > 0.0:
		var perfect_width := minf(_perfect_band * max_radius * 2.0, max_radius * 0.4)
		draw_arc(center, target_radius, 0.0, TAU, 96, _with_alpha(perfect_color, 0.25), perfect_width, true)

	draw_arc(center, target_radius, 0.0, TAU, 96, target_color, 2.0, true)

	var error := absf(_radius_ratio - _target_ratio)
	var color := moving_color
	if error <= _perfect_band:
		color = perfect_color
	elif error <= _good_band:
		color = good_color

	draw_circle(center, moving_radius, _with_alpha(color, 0.14))
	draw_arc(center, moving_radius, 0.0, TAU, 96, color, line_width, true)
	draw_circle(center, 3.0, Color(1.0, 1.0, 1.0, 0.35))


func _with_alpha(color: Color, alpha: float) -> Color:
	var result := color
	result.a = alpha
	return result
