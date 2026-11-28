extends Control

@onready var _breathing: BreathingSystem = $BreathingHUD
@onready var _game_over: Control = %GameOverOverlay


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_breathing.oxygen_depleted.connect(_on_oxygen_depleted)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://Scene/main_menu.tscn")


# Future mechanics (typing, eating) scale oxygen drain through this.
func set_drain_multiplier(multiplier: float) -> void:
	_breathing.set_drain_multiplier(multiplier)


func _on_oxygen_depleted() -> void:
	_breathing.visible = false
	_game_over.visible = true
	get_tree().paused = true


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scene/main_menu.tscn")
