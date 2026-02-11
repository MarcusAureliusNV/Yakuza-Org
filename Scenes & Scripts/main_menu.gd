extends Control


@onready var info_panel: Control = %InfoPanel

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("Left Click") and info_panel.visible:
		info_panel.hide()

func _on_tojo_clan_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes & Scripts/Tojo Clan/tojo_clan.tscn")


func _on_omi_alliance_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes & Scripts/Omi Alliance/omi_alliance.tscn")


func _on_more_info_pressed() -> void:
	info_panel.show()


func _on_quit_pressed() -> void:
	get_tree().quit()
