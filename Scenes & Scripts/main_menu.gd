extends Control


@onready var info_panel: Control = %InfoPanel

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("Left Click") and info_panel.visible:
		info_panel.hide()

func _on_tojo_clan_pressed() -> void:
	# 1. Load the specific JSON into the Global script
	Global.load_clan_data("res://Data/TojoClan.json")
	
	# 2. Change to the Tojo Clan scene
	get_tree().change_scene_to_file("res://Scenes & Scripts/Tojo Clan/tojo_clan.tscn")


func _on_omi_alliance_pressed() -> void:
	Global.load_clan_data("res://Data/OmiAlliance.json")
	
	get_tree().change_scene_to_file("res://Scenes & Scripts/Omi Alliance/omi_alliance.tscn")


func _on_more_info_pressed() -> void:
	info_panel.show()


func _on_quit_pressed() -> void:
	get_tree().quit()
