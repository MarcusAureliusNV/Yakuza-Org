extends Control

# --- NODES ---
@onready var hierarchy_tree: Tree = $VBoxContainer/HierarchyTree

# Login UI Nodes
@onready var login_panel: Panel = $LoginPanel
@onready var title_label: Label = $LoginPanel/TitleLabel
@onready var password_input: LineEdit = $LoginPanel/PasswordInput
@onready var error_label: Label = $LoginPanel/ErrorLabel

# --- VARIABLES ---
var current_attempt_item: TreeItem = null
var current_attempt_data: Dictionary = {}

func _ready() -> void:
	# 1. UI SETUP
	login_panel.hide()
	error_label.hide()
	
	# 2. TREE SETUP (Now with 3 Columns)
	hierarchy_tree.columns = 3
	hierarchy_tree.set_column_title(0, "Name")
	hierarchy_tree.set_column_title(1, "Rank")
	hierarchy_tree.set_column_title(2, "Shift Time") # New Column
	hierarchy_tree.set_column_titles_visible(true)
	hierarchy_tree.set_hide_root(true)
	
	# 3. CONNECT SIGNALS
	hierarchy_tree.item_activated.connect(_on_member_double_clicked)
	
	# Login Panel: Connect Button AND the "Enter" key on the input
	$LoginPanel/ConfirmButton.pressed.connect(_on_confirm_pressed)
	$LoginPanel/CancelButton.pressed.connect(_on_cancel_pressed)
	password_input.text_submitted.connect(_on_password_input_text_submitted) 
	
	if Global.active_clan_data.is_empty():
		return

	# 4. IMMERSION: Simulate random workers before building the tree
	simulate_background_activity()
	
	# 5. BUILD TREE
	setup_tree()

func _process(delta: float) -> void:
	# This runs every frame to update the timers
	update_all_timers()

# --- IMMERSION LOGIC ---
func simulate_background_activity() -> void:
	# Only run this if we haven't initialized this clan yet
	# (We check a flag in Global, or just check if anyone has a start_time)
	if Global.active_clan_data.get("initialized", false) == true:
		return

	var families = Global.active_clan_data["families"]
	var current_time = Time.get_unix_time_from_system()
	
	randomize() # Randomize the seed
	
	for fam in families.values():
		for rank in fam.values():
			for member in rank:
				# 30% chance a member is already working
				if randf() < 0.30: 
					member["is_clocked_in"] = true
					# Pick a random start time between 10 minutes and 8 hours ago
					var random_seconds_ago = randi_range(600, 28800)
					member["start_time"] = current_time - random_seconds_ago
	
	# Mark as initialized so we don't reset them if we switch menus
	Global.active_clan_data["initialized"] = true

# --- TREE BUILDING ---
func setup_tree() -> void:
	hierarchy_tree.clear()
	var root = hierarchy_tree.create_item()
	
	var families = Global.active_clan_data["families"]
	
	for family_name in families:
		var fam_node = create_header_item(root, family_name.to_upper(), Color.GOLD)
		var ranks = families[family_name]
		
		for rank_name in ranks:
			var rank_node = create_header_item(fam_node, rank_name, Color.INDIAN_RED)
			for member_data in ranks[rank_name]:
				create_member_item(rank_node, member_data)

func create_header_item(parent, text, color) -> TreeItem:
	var item = hierarchy_tree.create_item(parent)
	item.set_text(0, text)
	item.set_custom_color(0, color)
	item.set_selectable(0, false)
	item.set_selectable(1, false)
	item.set_selectable(2, false) # Disable selection on Time column
	return item

func create_member_item(parent, data) -> void:
	var item = hierarchy_tree.create_item(parent)
	item.set_text(0, data["name"])
	item.set_text(1, data["title"])
	item.set_text_alignment(2, HORIZONTAL_ALIGNMENT_RIGHT) # Align time to right
	item.set_metadata(0, data)
	
	update_visuals(item)

# --- REAL-TIME UPDATES ---
func update_all_timers() -> void:
	# We walk through the tree to update the time text for active workers
	var root = hierarchy_tree.get_root()
	if not root: return
	
	# Recursive function to find all members
	update_item_timer_recursive(root)

func update_item_timer_recursive(item: TreeItem) -> void:
	# 1. Get the data
	var data = item.get_metadata(0)
	
	# 2. Check if this item is a valid member and is clocked in
	if data and data.get("is_clocked_in", false):
		var start = data.get("start_time", Time.get_unix_time_from_system())
		var now = Time.get_unix_time_from_system()
		
		# --- THE FIX IS HERE ---
		# We force 'diff' to be an int immediately to remove decimals.
		var diff: int = int(now - start)
		
		# Now the math works because diff is an integer
		var hours = diff / 3600
		var minutes = (diff % 3600) / 60
		var seconds = diff % 60
		
		# Format string: %02d ensures we get "05" instead of just "5"
		var time_str = "%02d:%02d:%02d" % [hours, minutes, seconds]
		
		# Update column 2 (The 3rd column)
		item.set_text(2, time_str)
	
	# 3. Recursively check children (sub-ranks or members)
	var child = item.get_first_child()
	while child:
		update_item_timer_recursive(child)
		child = child.get_next()

# --- LOGIN LOGIC ---
func _on_member_double_clicked() -> void:
	var item = hierarchy_tree.get_selected()
	if item == null or item.get_metadata(0) == null: return
		
	var data = item.get_metadata(0)
	
	if data.get("is_clocked_in", false) == true:
		# LOGOUT
		data["is_clocked_in"] = false
		data.erase("start_time") # Clear the start time
		item.set_text(2, "") # Clear time text
		update_visuals(item)
		print("Logged out: " + data["name"])
	else:
		# LOGIN ATTEMPT
		open_login_panel(item, data)

func open_login_panel(item: TreeItem, data: Dictionary) -> void:
	current_attempt_item = item
	current_attempt_data = data
	
	title_label.text = "Password for: " + data["name"]
	password_input.text = ""
	error_label.hide()
	login_panel.show()
	password_input.grab_focus() # Focus so we can type immediately

func _on_confirm_pressed() -> void:
	var input_pass = password_input.text
	var correct_pass = current_attempt_data.get("password", "")
	
	if input_pass == correct_pass:
		# SUCCESS
		current_attempt_data["is_clocked_in"] = true
		# Set start time to NOW
		current_attempt_data["start_time"] = Time.get_unix_time_from_system()
		
		update_visuals(current_attempt_item)
		login_panel.hide()
	else:
		error_label.show()
		password_input.text = ""

func update_visuals(item: TreeItem) -> void:
	var data = item.get_metadata(0)
	if data.get("is_clocked_in", false):
		item.set_custom_color(0, Color.GREEN)
	else:
		item.set_custom_color(0, Color.WHITE)

func _on_cancel_pressed() -> void:
	login_panel.hide()
	current_attempt_item = null

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes & Scripts/mainMenu.tscn")

func _on_password_input_text_submitted(new_text: String) -> void:
	_on_confirm_pressed()


func _on_quit_button_pressed() -> void:
	get_tree().quit()
