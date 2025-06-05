extends Control
class_name Card
signal card_clicked
# CardData resource (this will hold all the card data)
var card_data: carddata
var card_size = Vector2(150, 150)  # Default card size

var hand_manager  # Reference to the script managing the hand
var is_in_fusion_menu: bool = false  # Flag to check if the card is shown in the FusionMenu
var is_highlighted = false  # Highlight flag
# Add this as a static variable at the top of Card.gd
static var texture_cache = {}
static var common_resources_loaded = false
static var element_frames_cache = {}
static var card_type_symbols_cache = {}

# Card.gd
#@export var name: String
@export var attack: int = 0
@export var health: int = 0
@export var armor: int = 0
@export var attack_speed: float = 0.0
@export var move_speed: float = 0.0
@export var attack_range: int = 0
@export var max_mana: int = 0
@export var health_regen: float = 0.0
@export var mana_regen: float = 0.0
@export var fusion_level: int = 0
@export var element: String
@export var ability_description: String
@export var card_image: Texture2D

# Element frame image paths - different frame for each element
var element_frames = {
	"Fire": "res://Assets/Frames/fire_card_frame.png",
	"None": "res://Assets/Frames/default_card_frame.png"  # Default frame
}

# Card type symbols - paths to textures
var card_type_symbols = {}

# UI components for the enhancements
var card_frame: TextureRect = null
var fusion_level_label: Label = null
var card_type_icon: TextureRect = null


var debug_mode = false  # Set to false by default, change to true only when needed

func debug_print(message):
	if debug_mode:
		print(message)
		

# Add this method to preload resources once
# Make create_scaled_texture static so it can be called from static methods
static func create_scaled_texture(original_texture: Texture2D, target_size: Vector2) -> Texture2D:
	if original_texture == null:
		return null
		
	var img = original_texture.get_image()
	img.resize(target_size.x, target_size.y, Image.INTERPOLATE_BILINEAR)
	
	return ImageTexture.create_from_image(img)

# Now the static method can call the static create_scaled_texture function
static func ensure_common_resources_loaded():
	if common_resources_loaded:
		return
		
	# Preload element frames
	var elements = ["Fire", "None"]
	for element in elements:
		var path = "res://Assets/Frames/" + (element.to_lower() if element != "None" else "default") + "_card_frame.png"
		element_frames_cache[element] = load(path)
	
	# Preload card type symbols
	for type in ["creature", "spell"]:
		var path = "res://Assets/Icons/" + type + "_icon.jpg"
		if FileAccess.file_exists(path):
			var texture = load(path)
			if texture:
				var scaled = Card.create_scaled_texture(texture, Vector2(18, 18))
				card_type_symbols_cache[type] = scaled
	
	common_resources_loaded = true

func _ready():
	print("Card is ready and should respond to clicks.")

	# Set the size of the card (Control node)
	custom_minimum_size = card_size
	set_size(card_size)
	
	# Initialize the card type symbols with proper scaling
	initialize_card_type_symbols()

	# Ensure the TextureRect exists
	var texture_rect := get_node_or_null("TextureRect")
	if texture_rect == null:
		# Create TextureRect if it doesn't exist
		texture_rect = TextureRect.new()
		texture_rect.name = "TextureRect"
		add_child(texture_rect)
	
	# Apply the card image from the card_data
	if card_data and card_data.image:
		var resized_image = preprocess_image(card_data.image)
		texture_rect.texture = resized_image  # Apply the resized image to the TextureRect
	else:
		print("Error: CardData or image not assigned.")
	
	# Set anchors and offsets to ensure the TextureRect fills the entire Control node
	texture_rect.anchor_left = 0.0
	texture_rect.anchor_top = 0.0
	texture_rect.anchor_right = 1.0
	texture_rect.anchor_bottom = 1.0
	texture_rect.offset_left = 5.0  # Inset slightly to leave room for frame
	texture_rect.offset_top = 5.0
	texture_rect.offset_right = -5.0
	texture_rect.offset_bottom = -5.0

	# Ensure the TextureRect scales properly
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # Cover the full area, maintain aspect ratio
	
	# Setup the visual enhancements
	setup_visual_enhancements()
	
	# Debugging information to check data is set correctly
	if card_data:
		print("Card name:", card_data.name)
		print("Attack:", card_data.attack, "Health:", card_data.health)
	else:
		print("Warning: card_data not set in _ready()")


# Initialize card type symbols with properly scaled textures
func initialize_card_type_symbols():
	var target_size = Vector2(18, 18)  # Small icon size
	
	# Debug print to help diagnose issues
	print("Initializing card type symbols...")
	
	# Check if the directory exists first
	var dir = DirAccess.open("res://Assets/Icons/")
	if dir == null:
		print("Warning: Icons directory does not exist. Creating fallback icons.")
		create_fallback_icon("creature")
		create_fallback_icon("spell")
		return
		
	# Try to load the source textures
	var creature_texture = load("res://Assets/Icons/creature_icon.jpg")
	var spell_texture = load("res://Assets/Icons/spell_icon.jpg")
	
	# Create the dictionary
	card_type_symbols = {}
	
	# Add each texture with error handling
	if creature_texture != null:
		card_type_symbols["creature"] = Card.create_scaled_texture(creature_texture, target_size)
		print("Loaded creature icon successfully")
	else:
		print("Failed to load creature icon texture")
		# Create a fallback texture
		create_fallback_icon("creature")
		
	if spell_texture != null:
		card_type_symbols["spell"] = create_scaled_texture(spell_texture, target_size)
		print("Loaded spell icon successfully")
	else:
		print("Failed to load spell icon texture")
		# Create a fallback texture
		create_fallback_icon("spell")
		
	# Debug print the result
	print("Card type symbols initialized with", card_type_symbols.size(), "icons")
	if card_type_symbols.size() > 0:
		print("Available icon types:", card_type_symbols.keys())

# Create a simple fallback icon
func create_fallback_icon(type: String):
	var img = Image.new()
	img.create(18, 18, false, Image.FORMAT_RGBA8)
	
	# Choose color based on type
	var color = Color(0.2, 0.8, 0.3) if type == "creature" else Color(0.8, 0.3, 0.8)
	
	# Fill the image with the color
	for x in range(18):
		for y in range(18):
			var dist = Vector2(x - 9, y - 9).length()
			if dist < 8:  # Create a circle
				img.set_pixel(x, y, color)
	
	# Create texture from image
	var texture = ImageTexture.create_from_image(img)
	card_type_symbols[type] = texture
	print("Created fallback icon for", type)

# Set the card data using the CardData resource
func set_card_data(data: carddata):
	card_data = data
	print("Setting card data for card:", card_data.name, " image:", card_data.image)
	initialize_with_card_data(card_data)
	
	# Make sure visual elements exist before updating
	if card_frame == null or fusion_level_label == null or card_type_icon == null:
		setup_visual_enhancements()
	
	update_card_visuals()

# Update visuals based on card data
func update_card_visuals():
	# At the start of update_card_visuals
	if card_type_symbols.size() == 0:
		initialize_card_type_symbols()
	if card_data:
		# Check if card frame exists before trying to update
		if card_frame != null:
			# Update the card frame image based on element
			var element = card_data.element if card_data.element else "None"
			update_card_frame(element)
		else:
			print("Warning: card_frame is null, visual enhancements may not be initialized")
		
		# Check if fusion level label exists
		if fusion_level_label != null:
			# Update fusion level
			fusion_level_label.text = str(card_data.fusion_level)
		
		# Check if card type icon exists
		if card_type_icon != null:
			# Safely get the card type with fallback to "creature"
			var card_type = "creature"
			if card_data.get("card_type") != null:
				card_type = card_data.card_type
			
			# First check if we have any icons at all
			if card_type_symbols.size() > 0:
				# Then check if we have the specific icon
				if card_type_symbols.has(card_type):
					card_type_icon.texture = card_type_symbols[card_type]
					print("Set card type icon to:", card_type)
				elif card_type_symbols.has("creature"):
					card_type_icon.texture = card_type_symbols["creature"]
					print("Using default creature icon")
				else:
					# Use any available icon
					var first_key = card_type_symbols.keys()[0]
					card_type_icon.texture = card_type_symbols[first_key]
					print("Using first available icon:", first_key)
				card_type_icon.visible = true
			else:
				# No icons available
				card_type_icon.visible = false
				print("Warning: No card type icons available")

		# Call the original visual update to handle the main image
		update_original_visuals()
	else:
		print("Warning: card_data is null in update_card_visuals()")


# Add this after initializing cards
func refresh_card_icons():
	if card_type_icon and card_type_symbols.size() > 0:
		var card_type = "creature"  # Default
		if card_data and card_data.get("card_type") != null:
			card_type = card_data.card_type
			
		if card_type_symbols.has(card_type):
			card_type_icon.texture = card_type_symbols[card_type]
			card_type_icon.visible = true

# Update the card frame based on element
func update_card_frame(element: String):
	if not card_frame:
		return
		
	# Check if the frames directory exists
	var dir = DirAccess.open("res://Assets/Frames/")
	if dir == null:
		print("Warning: Frames directory does not exist. Creating directory...")
		DirAccess.make_dir_recursive_absolute("res://Assets/Frames/")
		create_fallback_frame()
		return
		
	# Get the frame path for this element (or default if not found)
	var frame_path = element_frames.get(element, element_frames["None"])
	var frame_texture = load(frame_path)
	
	if frame_texture:
		card_frame.texture = frame_texture
		print("Updated card frame to:", frame_path)
	else:
		print("Failed to load frame image:", frame_path)
		# If we can't load the specific element frame, try the default
		if element != "None":
			var default_texture = load(element_frames["None"])
			if default_texture:
				card_frame.texture = default_texture
				print("Using default frame instead")
			else:
				create_fallback_frame()
		else:
			create_fallback_frame()

func initialize_with_card_data(card_data: carddata):
	name = card_data.name
	attack = card_data.attack
	health = card_data.health
	armor = card_data.armor
	attack_speed = card_data.attack_speed
	move_speed = card_data.move_speed
	attack_range = card_data.attack_range
	max_mana = card_data.max_mana
	health_regen = card_data.health_regen
	mana_regen = card_data.mana_regen
	fusion_level = card_data.fusion_level
	element = card_data.element
	ability_description = card_data.ability_description

	# Set the image texture on TextureRect directly
	if has_node("TextureRect"):
		var texture_rect = get_node("TextureRect")
		if card_data.image:
			texture_rect.texture = card_data.image
			print("Image set directly on TextureRect:", card_data.image)
		else:
			print("No image found for this card!")

# Function to return the ability description for display
func get_ability_description() -> String:
	return ability_description

# This contains your original visual update logic for the card image
func update_original_visuals():
	# Set card size
	set_size(card_size)
	
	# Update the TextureRect with the card's image
	if has_node("TextureRect"):
		var texture_rect = get_node("TextureRect")
		var resized_image = preprocess_image(card_data.image)
		texture_rect.texture = resized_image
	else:
		print("Error: TextureRect not found!")

# Preprocess the image to resize it to match the card size
# Then replace your preprocess_image function with this:
func preprocess_image(texture: Texture2D) -> Texture2D:
	if texture == null:
		print("Warning: Attempting to preprocess null texture")
		return null
	
	# Use the texture's ID as a cache key
	var texture_id = texture.get_instance_id()
	
	# Check if we already processed this texture
	if texture_cache.has(texture_id):
		return texture_cache[texture_id]
	
	# Process the image if not in cache
	var img = texture.get_image()
	img.resize(card_size.x - 10, card_size.y - 10)
	
	var new_texture = ImageTexture.create_from_image(img)
	texture_cache[texture_id] = new_texture
	return new_texture
	
func setup_visual_enhancements():
	# Only setup once
	if card_frame != null:
		return
		
	print("Setting up visual enhancements for card")
	
	# Create card frame TextureRect
	card_frame = TextureRect.new()
	card_frame.name = "CardFrame"
	card_frame.mouse_filter = MOUSE_FILTER_IGNORE  # Pass through mouse events
	add_child(card_frame)
	
	# Move the frame to the back (lowest z-index)
	move_child(card_frame, 0)
	
	# Position the frame to cover the entire card
	card_frame.set_anchors_preset(PRESET_FULL_RECT)
	card_frame.offset_left = 0
	card_frame.offset_top = 0 
	card_frame.offset_right = 0
	card_frame.offset_bottom = 0
	card_frame.expand = true  # Make it resize with the card
	
	# Set the initial frame texture based on element (if card_data is available)
	if card_data:
		var element = card_data.element if card_data.element else "None"
		update_card_frame(element)
	else:
		# Use default frame
		var default_texture = load(element_frames["None"])
		if default_texture:
			card_frame.texture = default_texture
		else:
			create_fallback_frame()
	
	# Create fusion level background
	var fusion_bg = ColorRect.new()
	fusion_bg.name = "FusionLevelBackground"
	fusion_bg.size = Vector2(20, 20)  # Smaller size
	fusion_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	fusion_bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(fusion_bg)
	
	# Create fusion level indicator
	fusion_level_label = Label.new()
	fusion_level_label.name = "FusionLevelLabel"
	fusion_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fusion_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fusion_level_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(fusion_level_label)
	
	# Create card type icon with explicit Canvas Layer
	card_type_icon = TextureRect.new()
	card_type_icon.name = "CardTypeIcon"
	card_type_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_type_icon.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(card_type_icon)
	
	# Ensure icon is on top
	card_type_icon.z_index = 10
	
	# Apply styles to these elements
	style_elements()
	
	# Position these elements
	position_visual_elements()
	
	print("Visual enhancements setup complete")

# Create a simple fallback frame if image can't be loaded
func create_fallback_frame():
	var img = Image.new()
	img.create(card_size.x, card_size.y, false, Image.FORMAT_RGBA8)
	
	# Create a simple border
	var border_width = 2
	var color = Color(0.7, 0.7, 0.7)  # Default gray
	
	# Fill the border
	for x in range(card_size.x):
		for y in range(card_size.y):
			if x < border_width or x >= card_size.x - border_width or y < border_width or y >= card_size.y - border_width:
				img.set_pixel(x, y, color)
	
	var texture = ImageTexture.create_from_image(img)
	card_frame.texture = texture
	print("Created fallback card frame")

# Apply styles to the elements
func style_elements():
	# Style the fusion level label
	fusion_level_label.add_theme_font_size_override("font_size", 14)  # Smaller font
	fusion_level_label.add_theme_color_override("font_color", Color(1, 1, 1))
	fusion_level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	fusion_level_label.add_theme_constant_override("outline_size", 1)
	
	# Make sure fusion level is on top
	fusion_level_label.z_index = 10

# Position all the visual elements
func position_visual_elements():
	# Position the fusion level in top-right corner
	var fusion_bg = get_node_or_null("FusionLevelBackground")
	if fusion_bg:
		fusion_bg.position = Vector2(size.x - fusion_bg.size.x - 5, 5)
		fusion_level_label.position = Vector2(size.x - 10, 10)  # Centered on the background
		fusion_level_label.size = Vector2(15, 15)  # Explicit size for the label
		
		# Make sure background is on top as well
		fusion_bg.z_index = 9
	else:
		print("Warning: FusionLevelBackground not found")
	
	# Position the card type icon in top-left corner with explicit size and position
	card_type_icon.position = Vector2(5, 5)
	card_type_icon.size = Vector2(18, 18)  # Smaller icon size
	
	# Debug icon visibility
	if card_type_icon.texture:
		print("Card type icon has texture, size:", card_type_icon.size)
	else:
		print("Card type icon has no texture")

# Integrate with your existing toggle_highlight method
func toggle_highlight():
	# Only cards outside the fusion menu can be highlighted
	if not is_in_fusion_menu:
		is_highlighted = !is_highlighted
		if is_highlighted:
			modulate = Color(1, 1, 0.5)  # Highlight the card visually
		else:
			modulate = Color(1, 1, 1)  # Remove highlight

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if card_data:
			print("Mouse button pressed. Card level:", card_data.fusion_level)
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("Left mouse button pressed. Processing input.")
			if card_data:
				GlobalSignals.emit_signal("card_clicked", card_data)

			if is_in_fusion_menu:
				# Only call `hand_manager.add_card(self)` if hand_manager is valid
				if hand_manager != null:
					hand_manager.add_card(self)
				accept_event()
			else:
				# In the normal game (hand context)
				if not is_highlighted:
					# Only highlight if we actually have a hand_manager
					if hand_manager != null:
						hand_manager.highlight_card(self)
				accept_event()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			print("Right mouse button pressed. Unhighlighting card.")

			if not is_in_fusion_menu:
				if is_highlighted:
					toggle_highlight()
					# Only remove from the hand_manager if it's not null
					if hand_manager != null:
						hand_manager.remove_from_selected(self)
				accept_event()

# Method to apply the position of the card
func apply_position(new_position: Vector2):
	self.position = new_position  # Set the position of the card
