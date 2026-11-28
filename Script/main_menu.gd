extends Control

# Kolom ini akan muncul di Inspector sebelah kanan.
# Nanti kalau scene gameplay/options sudah dibuat, tinggal pilih file .tscn-nya di sana!
@export_file("*.tscn") var play_scene: String = "res://Scene/main.tscn"
@export_file("*.tscn") var options_scene: String


func _ready() -> void:
	# Memastikan kursor mouse selalu terlihat saat di Main Menu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_play_button_pressed() -> void:
	if play_scene != "":
		get_tree().change_scene_to_file(play_scene)
	else:
		print("Tombol PLAY diklik! (Scene Play belum diisi di Inspector)")


func _on_options_button_pressed() -> void:
	if options_scene != "":
		get_tree().change_scene_to_file(options_scene)
	else:
		print("Tombol OPTIONS diklik! (Scene Options belum diisi di Inspector)")


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_option_button_pressed() -> void:
	pass # Replace with function body.
