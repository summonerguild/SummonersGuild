extends Control

# Track current page and total pages
var current_page = 0
var total_pages = 2

# Store the current creature for page navigation
var current_creature = null

# UI node references
@onready var card_image = $CardPanel/PanelContainer/CardImage
@onready var name_label = $CardPanel/CardDetails/NameLabel
@onready var attack_label = $CardPanel/CardDetails/AttackLabel
@onready var attackspeed_label = $CardPanel/CardDetails/AttackSpeedLabel
@onready var health_label = $CardPanel/CardDetails/HealthLabel
@onready var armor_label = $CardPanel/CardDetails/ArmorLabel
@onready var ability_label = $CardPanel/CardDetails/AbilityLabel

# New UI elements (make sure to add these to your scene)
@onready var page_indicator = $CardPanel/PageControls/PageIndicator
@onready var prev_button = $CardPanel/PageControls/PrevButton
@onready var next_button = $CardPanel/PageControls/NextButton

# Additional stat labels for Page 2
@onready var move_speed_label = $CardPanel/CardDetails/MoveSpeedLabel
@onready var attack_range_label = $CardPanel/CardDetails/AttackRangeLabel
@onready var max_mana_label = $CardPanel/CardDetails/MaxManaLabel
@onready var mana_regen_label = $CardPanel/CardDetails/ManaRegenLabel
@onready var health_regen_label = $CardPanel/CardDetails/HealthRegenLabel
@onready var element_label = $CardPanel/CardDetails/ElementLabel
@onready var fusion_level_label = $CardPanel/CardDetails/FusionLevelLabel

func _ready():
	# Initialize page controls
	if prev_button and next_button:
		prev_button.connect("pressed", Callable(self, "_on_prev_button_pressed"))
		next_button.connect("pressed", Callable(self, "_on_next_button_pressed"))
	
	# Hide the box initially
	visible = false

func show_creature_info(creature):
	current_creature = creature
	current_page = 0
	update_page()
	self.visible = true

func update_page():
	if not current_creature:
		return
		
	# Update page indicator
	if page_indicator:
		page_indicator.text = "Page " + str(current_page + 1) + " / " + str(total_pages)
	
	# Common updates for all pages
	update_creature_image()
	update_creature_name()
	
	# Show/hide elements based on current page
	if current_page == 0:
		# Page 1: Basic Combat Stats
		show_basic_stats()
		hide_advanced_stats()
	else:
		# Page 2: Advanced Stats
		hide_basic_stats()
		show_advanced_stats()

func update_creature_image():
	var image_to_display = null
	if current_creature is Node:
		# Try to get a property named "card_image" using get()
		var local_image = current_creature.get("card_image")
		if local_image:
			image_to_display = local_image
		else:
			# Attempt to retrieve card_data via get("card_data")
			var cd = current_creature.get("card_data")
			if cd and cd.image:
				image_to_display = cd.image
	elif current_creature is Resource:
		if current_creature.image:
			image_to_display = current_creature.image
	
	if image_to_display:
		card_image.texture = image_to_display
		card_image.custom_minimum_size = Vector2(20, 20)
		card_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	else:
		card_image.texture = null

func update_creature_name():
	# Determine the card's name
	var card_name = ""
	if current_creature is Node:
		var cd = current_creature.get("card_data")
		if cd:
			card_name = str(cd.name)
		else:
			card_name = current_creature.name
	elif current_creature is Resource:
		card_name = str(current_creature.name)
	name_label.text = "Name: " + card_name

func show_basic_stats():
	# Make basic stat labels visible
	if attack_label:
		attack_label.visible = true
		attack_label.text = "Attack: " + str(get_creature_stat("attack"))
	
	if attackspeed_label:
		attackspeed_label.visible = true
		attackspeed_label.text = "Attack Speed: " + str(get_creature_stat("attack_speed")) + " attacks/sec"
	
	if health_label:
		health_label.visible = true
		health_label.text = "Health: " + str(get_creature_stat("health"))
	
	if armor_label:
		armor_label.visible = true
		armor_label.text = "Armor: " + str(get_creature_stat("armor"))
	
	if ability_label:
		ability_label.visible = true
		ability_label.text = "Ability: " + get_creature_ability_description()

func hide_basic_stats():
	# Hide basic stat labels
	if attack_label: attack_label.visible = false
	if attackspeed_label: attackspeed_label.visible = false
	if health_label: health_label.visible = false
	if armor_label: armor_label.visible = false
	if ability_label: ability_label.visible = false

func show_advanced_stats():
	# Make advanced stat labels visible and populate them
	if move_speed_label:
		move_speed_label.visible = true
		move_speed_label.text = "Move Speed: " + str(get_creature_stat("move_speed"))
	
	if attack_range_label:
		attack_range_label.visible = true
		attack_range_label.text = "Attack Range: " + str(get_creature_stat("attack_range"))
	
	if max_mana_label:
		max_mana_label.visible = true
		max_mana_label.text = "Max Mana: " + str(get_creature_stat("max_mana"))
	
	if mana_regen_label:
		mana_regen_label.visible = true
		mana_regen_label.text = "Mana Regen: " + str(get_creature_stat("mana_regen")) + "/sec"
	
	if health_regen_label:
		health_regen_label.visible = true
		health_regen_label.text = "Health Regen: " + str(get_creature_stat("health_regen")) + "/sec"
	
	if element_label:
		element_label.visible = true
		element_label.text = "Element: " + str(get_creature_stat("element"))
	
	if fusion_level_label:
		fusion_level_label.visible = true
		fusion_level_label.text = "Fusion Level: " + str(get_creature_stat("fusion_level"))

func hide_advanced_stats():
	# Hide advanced stat labels
	if move_speed_label: move_speed_label.visible = false
	if attack_range_label: attack_range_label.visible = false
	if max_mana_label: max_mana_label.visible = false
	if mana_regen_label: mana_regen_label.visible = false
	if health_regen_label: health_regen_label.visible = false
	if element_label: element_label.visible = false
	if fusion_level_label: fusion_level_label.visible = false

# Helper function to get stat value, handling different types of creatures
func get_creature_stat(stat_name: String):
	if current_creature is Node:
		if current_creature.has_method("get") and stat_name in current_creature:
			return current_creature.get(stat_name)
		else:
			# Try to get it from card_data
			var cd = current_creature.get("card_data")
			if cd and stat_name in cd:
				return cd.get(stat_name)
	elif current_creature is Resource and stat_name in current_creature:
		return current_creature.get(stat_name)
	
	return "N/A"  # Return a placeholder if stat not found

# Helper function to get ability description
func get_creature_ability_description() -> String:
	if current_creature is Node and current_creature.has_method("get_ability_description"):
		return current_creature.get_ability_description()
	elif current_creature is Resource and current_creature.has_method("get_ability_description"):
		return current_creature.get_ability_description()
	elif current_creature is Node and current_creature.get("ability_description") != null:
		return current_creature.ability_description
	elif current_creature is Resource and current_creature.get("ability_description") != null:
		return current_creature.ability_description
	
	return "No ability information available"

func _on_prev_button_pressed():
	if current_page > 0:
		current_page -= 1
		update_page()

func _on_next_button_pressed():
	if current_page < total_pages - 1:
		current_page += 1
		update_page()
