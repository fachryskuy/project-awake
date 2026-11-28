extends Control

@export var typing_drain_multiplier: float = 3.0

@onready var breathing: BreathingSystem = $Margin/HBox/SystemHolder/BreathingSystem
@onready var typing_button: Button = %TypingButton
@onready var choke_button: Button = %ChokeButton
@onready var reset_button: Button = %ResetButton
@onready var status_label: Label = %StatusLabel
@onready var signal_label: Label = %SignalLabel


func _ready() -> void:
	typing_button.toggled.connect(_on_typing_toggled)
	choke_button.pressed.connect(_on_choke_pressed)
	reset_button.pressed.connect(_on_reset_pressed)

	breathing.oxygen_changed.connect(_on_oxygen_changed)
	breathing.breath_result.connect(_on_breath_result)
	breathing.oxygen_depleted.connect(_on_oxygen_depleted)
	breathing.choke_started.connect(_on_choke_started)
	breathing.choke_resolved.connect(_on_choke_resolved)

	_set_signal("Ready")
	_refresh_status()


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	match key_event.physical_keycode:
		KEY_T:
			_set_typing(not typing_button.button_pressed)
			get_viewport().set_input_as_handled()
		KEY_C:
			_on_choke_pressed()
			get_viewport().set_input_as_handled()
		KEY_R:
			_on_reset_pressed()
			get_viewport().set_input_as_handled()


func _set_typing(enabled: bool) -> void:
	typing_button.set_pressed_no_signal(enabled)
	_on_typing_toggled(enabled)


func _on_typing_toggled(enabled: bool) -> void:
	breathing.set_drain_multiplier(typing_drain_multiplier if enabled else 1.0)
	_refresh_status()


func _on_choke_pressed() -> void:
	if not breathing.running:
		_set_signal("choke ignored (system stopped)")
		return
	breathing.trigger_choke()


func _on_reset_pressed() -> void:
	_set_typing(false)
	breathing.reset()
	_set_signal("reset()")


func _on_oxygen_changed(value: float) -> void:
	_refresh_status(value)


func _on_breath_result(result: BreathingSystem.Result) -> void:
	var result_name := "Miss"
	match result:
		BreathingSystem.Result.PERFECT:
			result_name = "Perfect"
		BreathingSystem.Result.GOOD:
			result_name = "Good"
	_set_signal("breath_result: %s" % result_name)


func _on_oxygen_depleted() -> void:
	_set_signal("oxygen_depleted")
	_refresh_status()


func _on_choke_started() -> void:
	_set_signal("choke_started")
	_refresh_status()


func _on_choke_resolved(success: bool) -> void:
	_set_signal("choke_resolved: %s" % ("gasp" if success else "failed"))
	_refresh_status()


func _refresh_status(value: float = -1.0) -> void:
	var shown := value if value >= 0.0 else breathing.oxygen
	status_label.text = "Drain multiplier: %.1fx\nSystem: %s\nOxygen signal: %.1f" % [
		breathing.drain_multiplier,
		"running" if breathing.running else "stopped",
		shown,
	]


func _set_signal(text: String) -> void:
	signal_label.text = "Last signal:\n%s" % text
