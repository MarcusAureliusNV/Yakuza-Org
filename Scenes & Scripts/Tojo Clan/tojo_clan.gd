extends Control

## Unique nodes
# Tree where there is everything
@onready var tree: Tree = %HierarchyTree

# Fade out on quit button
@onready var animation_player: AnimationPlayer = %AnimationPlayer

# Panels to show/hide
@onready var login_panel: Panel = %LoginPanel
@onready var action_panel: Panel = %ActionPanel

# Input fields and labels
@onready var password_input: LineEdit = %PasswordInput
@onready var error_label: Label = %ErrorLabel
@onready var title_label: Label = %TitleLabel

# Buttons
@onready var pause_button: Button = %PauseButton
@onready var working_person: Label = %WorkingPersonLabel

# Label to show the name of the logged in
@onready var welcoming_label: Label = %WelcomingLabel

## Variables
# This holds the specific row of the tree we clicked on
var current_item: TreeItem = null
# This holds the "save data" (dictionary) of that person
var current_data: Dictionary = {}

# We check this to know if the game has already started random workers
var has_started: bool = false


func _ready() -> void:
	# Setup columns, inspector apparently can't add them
	tree.set_column_title(0, "Name")
	tree.set_column_title(1, "Rank")
	tree.set_column_title(2, "Status")
	tree.set_column_title(3, "Time")

	# To initialize data
	if Global.active_clan_data.is_empty():
		return
	
	# If it's initialized, get some workers to work for it to be more inmersive
	if Global.active_clan_data.get("initialized") != true:
		_randomize_workers()

	_build_visual_tree()


func _process(delta: float) -> void:
	# We need the root to start checking people
	var root = tree.get_root()
	
	if root != null:
		_update_timers_loop(root)

## Time logic
# This function is called every frame to update the timer for the workers
func _update_timers_loop(item: TreeItem) -> void:
	# 1. Get the data from the hidden storage (metadata)
	var data = item.get_metadata(0)
	
	# 2. Check if they are actually working (Clocked In AND Not Paused)
	if data != null:
		var is_working = data.get("is_clocked_in", false)
		var is_paused = data.get("is_paused", false)
		
		if is_working and not is_paused:
			# Get current computer time
			var now = Time.get_unix_time_from_system()
			# Get when they started (default to 'now' if missing)
			var start = data.get("start_time", now)
			# Get how long they were paused (deductions)
			var deduction = data.get("pause_deduction", 0)
			
			var total_seconds = int(now - start - deduction)
			
			# Convert seconds into 00:00:00 format
			var time_string = Time.get_time_string_from_unix_time(total_seconds)
			
			# Set the updated time on the fourth column
			item.set_text(3, time_string)
			
	# loop to complete all rows
	var child = item.get_first_child()
	while child != null:
		_update_timers_loop(child)
		child = child.get_next()


## Tree stuff

func _on_hierarchy_tree_item_activated() -> void:
	
	current_item = tree.get_selected()
	if current_item == null: 
		return
		
	current_data = current_item.get_metadata(0)
	if current_data == null:
		return

	# Bool to check if it's working, in order to show the action menu
	var is_working = current_data.get("is_clocked_in", false)

	if is_working == true:
		_open_action_menu()
	else:
		_open_login_menu()


func _open_login_menu() -> void:
	_close_all_panels()
	login_panel.show()
	
	# Set title text to show the current login attempt
	title_label.text = "Login: " + current_data["name"]
	
	# Clear previous password and focus so we can type
	password_input.text = ""
	# So the user doesn't have to click to start writing
	password_input.grab_focus()


func _open_action_menu() -> void:
	action_panel.show()
	
	# Check if they are paused to change the button text
	if current_data.get("is_paused", false) == true:
		pause_button.text = "RESUME WORK"
	else:
		pause_button.text = "PAUSE WORK"

func _on_login_pressed() -> void:
	# Check password
	var input_text = password_input.text
	var real_password = current_data.get("password", "")
	
	if input_text == real_password:
		# SUCCESS
		current_data["is_clocked_in"] = true
		current_data["start_time"] = Time.get_unix_time_from_system()
		current_data["status_text"] = "WORKING"
		
		# Update visuals and close
		_update_row_color(current_item)
		_close_all_panels()
	else:
		# if the password is wrong the error label shows and the password resets
		error_label.show()
		password_input.text = ""


func _on_password_enter(new_text: String) -> void:
	# Just call the button function
	_on_login_pressed()


func _on_pause_pressed() -> void:
	var now = Time.get_unix_time_from_system()
	var is_paused = current_data.get("is_paused", false)
	
	if is_paused:
		# RESUME LOGIC
		current_data["is_paused"] = false
		current_data["status_text"] = "WORKING"
		
		# Calculate how long we were stopped
		var time_stopped_at = current_data.get("pause_start_marker", now)
		var time_paused = now - time_stopped_at
		
		# Add to the "deduction" pile
		var current_deduction = current_data.get("pause_deduction", 0)
		current_data["pause_deduction"] = current_deduction + time_paused
		
	else:
		# PAUSE LOGIC
		current_data["is_paused"] = true
		current_data["status_text"] = "PAUSED"
		# Mark the time we pressed pause
		current_data["pause_start_marker"] = now
		
	_update_row_color(current_item)
	_close_all_panels()


func _on_logout_pressed() -> void:
	# Reset everything
	current_data["is_clocked_in"] = false
	current_data["is_paused"] = false
	current_data["status_text"] = "OFFLINE"
	
	# Clear the time text manually
	current_item.set_text(3, "")
	
	_update_row_color(current_item)
	_close_all_panels()


func _close_all_panels() -> void:
	login_panel.hide()
	action_panel.hide()
	error_label.hide()


## Visual Enhacers

func _update_row_color(item: TreeItem) -> void:
	# Get status text (Default to OFFLINE if missing)
	var status = current_data.get("status_text", "OFFLINE")
	
	# Update the Status Column (Column 2)
	item.set_text(2, status)
	
	# Change colors based on status
	if status == "WORKING":
		item.set_custom_color(0, Color.GREEN) 
		item.set_custom_color(2, Color.GREEN) 
	elif status == "PAUSED":
		item.set_custom_color(0, Color.YELLOW)
		item.set_custom_color(2, Color.YELLOW)
	else:
		item.set_custom_color(0, Color.WHITE)
		item.set_custom_color(2, Color.GRAY)


## Setup functions (Only runs once)

func _randomize_workers() -> void:
	randomize() 
	var families = Global.active_clan_data["families"]
	var now = Time.get_unix_time_from_system()
	
	# Loop through all data to pick random workers
	for fam in families.values():
		for rank in fam.values():
			for member in rank:
				# 30% Chance
				if randf() < 0.3:
					member["is_clocked_in"] = true
					member["status_text"] = "WORKING"
					# Start random time
					member["start_time"] = now - randi_range(600, 20000)
	
	# Mark global data as ready so it only plays once
	Global.active_clan_data["initialized"] = true


func _build_visual_tree() -> void:
	tree.clear()
	var root = tree.create_item()
	var families = Global.active_clan_data["families"]
	
	for fam_name in families:
		# Create Header
		var fam_item = tree.create_item(root)
		fam_item.set_text(0, fam_name)
		fam_item.set_custom_color(0, Color.GOLD)
		fam_item.set_selectable(0, false) # Can't click headers
		
		for rank_name in families[fam_name]:
			# Create Sub-Header
			var rank_item = tree.create_item(fam_item)
			rank_item.set_text(0, rank_name)
			rank_item.set_custom_color(0, Color.INDIAN_RED)
			rank_item.set_selectable(0, false)
			
			for member in families[fam_name][rank_name]:
				# Create Member
				var mem_item = tree.create_item(rank_item)
				mem_item.set_text(0, member["name"])
				mem_item.set_text(1, member["title"])
				
				# Save the data in the item's metadata (The Backpack)
				mem_item.set_metadata(0, member)
				
				# Save this item to our variables to update color immediately
				current_data = member
				_update_row_color(mem_item)


# --- BUTTON CONNECTIONS (Connected via Editor) ---

func _on_confirm_button_pressed() -> void:
	var input_text = password_input.text
	var real_password = current_data.get("password", "")
	
	if input_text == real_password:
		# SUCCESS
		current_data["is_clocked_in"] = true
		current_data["start_time"] = Time.get_unix_time_from_system()
		current_data["status_text"] = "WORKING"
		
		# Updating the upper title with the current worker's name
		welcoming_label.text = "Welcome, " + current_data["name"] + "!"
		# Aligning it again because it unaligns with the new name
		welcoming_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		welcoming_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		_update_row_color(current_item)
		_close_all_panels()
	else:
		# FAIL
		error_label.show()
		password_input.text = ""

func _on_cancel_button_pressed() -> void:
	_close_all_panels()

func _on_pause_button_pressed() -> void:
	# This replaces your old "_on_pause_pressed"
	var now = Time.get_unix_time_from_system()
	# Check if we are CURRENTLY paused (before the click)
	var was_paused = current_data.get("is_paused", false)
	
	if was_paused:
		# RESUME LOGIC
		current_data["is_paused"] = false
		current_data["status_text"] = "WORKING"
		
		# Calculate how long we were stopped
		var time_stopped_at = current_data.get("pause_start_marker", now)
		var time_paused = now - time_stopped_at
		
		# Add to the "deduction" pile
		var current_deduction = current_data.get("pause_deduction", 0)
		current_data["pause_deduction"] = current_deduction + time_paused
	else:
		# PAUSE LOGIC
		current_data["is_paused"] = true
		current_data["status_text"] = "PAUSED"
		current_data["pause_start_marker"] = now
		
	_update_row_color(current_item)
	_close_all_panels()

func _on_logout_button_pressed() -> void:
	# This replaces your old "_on_logout_pressed"
	current_data["is_clocked_in"] = false
	current_data["is_paused"] = false
	current_data["status_text"] = "OFFLINE"
	# Updates title text so it has no name
	welcoming_label.text = "Good work, " + current_data["name"] + ". See you soon!"
	welcoming_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	welcoming_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Clear the time text manually
	current_item.set_text(3, "")
	
	_update_row_color(current_item)
	_close_all_panels()

func _on_close_button_pressed() -> void:
	_close_all_panels()

func _on_password_input_text_submitted(new_text: String) -> void:
	_on_confirm_button_pressed()


func _on_quit_button_pressed() -> void:
	animation_player.play("out")
	await animation_player.animation_finished
	get_tree().change_scene_to_file("res://Scenes & Scripts/mainMenu.tscn")
