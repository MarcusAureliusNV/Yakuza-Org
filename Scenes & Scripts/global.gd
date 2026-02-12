extends Node

# This variable will hold the JSON data
var active_clan_data: Dictionary = {}

# Function to load the JSON file into the dictionary
func load_clan_data(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_text = file.get_as_text()
		active_clan_data = JSON.parse_string(json_text)
		print("Successfully loaded: ", file_path)
	else:
		print("Error: File not found at ", file_path)
