extends Control

signal eye_open_state_changed(is_open: bool)

const DRYNESS_RATE := 5.0
const CLOSED_THRESHOLD := 0.08
const FULL_OPEN_THRESHOLD := 0.999
const MAX_RED_TINT_ALPHA := 0.5

var opening := 0.0
var dryness := 0.0
var _dragging := false
var _dragging_upper_lid := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _process(delta: float) -> void:
	if is_open() and dryness < 100.0:
		dryness = minf(dryness + DRYNESS_RATE * delta, 100.0)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_dragging_upper_lid = event.position.y <= size.y * 0.5
			accept_event()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var movement: float = event.relative.y / maxf(size.y * 0.5, 1.0)
		var opening_change := movement
		if _dragging_upper_lid:
			opening_change = -movement
		_set_opening(clampf(opening + opening_change, 0.0, 1.0))
		accept_event()


func _set_opening(value: float) -> void:
	var was_open := is_open()
	opening = value
	var currently_open := is_open()
	if not currently_open:
		dryness = 0.0
	if was_open != currently_open:
		eye_open_state_changed.emit(currently_open)
	queue_redraw()


func is_open() -> bool:
	return opening > CLOSED_THRESHOLD


func _draw() -> void:
	var tint_alpha := dryness / 100.0 * MAX_RED_TINT_ALPHA
	if tint_alpha > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.08, 0.08, tint_alpha))

	var eye_opening := opening if is_open() else 0.0
	var center_y := size.y * 0.5
	var lid_travel := size.y * 0.5 * eye_opening
	if eye_opening < FULL_OPEN_THRESHOLD:
		var curve_height := size.y * 0.5 * eye_opening * (1.0 - eye_opening)
		var upper_edge := PackedVector2Array()
		var lower_edge := PackedVector2Array()
		var upper_lid := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0)])
		var lower_lid := PackedVector2Array([Vector2(0.0, size.y), size])
		var segments := 48

		for index in range(segments + 1):
			var progress := float(index) / float(segments)
			var x := size.x * progress
			var curve := sin(PI * progress)
			upper_edge.append(Vector2(x, center_y - lid_travel - curve_height * curve))
			lower_edge.append(Vector2(x, center_y + lid_travel + curve_height * curve))

		for index in range(segments, -1, -1):
			upper_lid.append(upper_edge[index])
			lower_lid.append(lower_edge[index])

		draw_colored_polygon(upper_lid, Color.BLACK)
		draw_colored_polygon(lower_lid, Color.BLACK)
		var eyelid_line_color := Color(0.16, 0.07, 0.07)
		if eye_opening <= CLOSED_THRESHOLD:
			draw_line(
				Vector2(0.0, center_y),
				Vector2(size.x, center_y),
				eyelid_line_color,
				1.0,
				true
			)
		else:
			draw_polyline(upper_edge, eyelid_line_color, 1.0, true)
			draw_polyline(lower_edge, eyelid_line_color, 1.0, true)
