extends Control

signal deck_selected(selected_deck)

var available_cards = []          # All the card data for deck building
var selected_deck = []            # Player's final chosen deck
const MAX_DECK_SIZE = 10

# We'll track which cards are "highlighted" with a dictionary.
var highlighted_cards := {}

# Card factory reference
var card_factory

func _ready():
	# Create the card factory
	card_factory = load("res://Scripts/cardfactory.gd").new()
	add_child(card_factory)
	card_factory.setup_deck()
	
	# Load available cards
	available_cards = card_factory.card_pool["lvl0cards"]
	print("Available cards loaded:", available_cards.size())
	
	# Display the cards in the grid
	display_available_cards()
	
	# Update the deck count label
	update_deck_count_label()

func display_available_cards():
	if available_cards.is_empty():
		print("No cards available for selection!")
		return

	var grid_container = $Panel/GridContainer

	for card_data in available_cards:
		# Create a card from the factory (no hand_manager references)
		var card_instance = card_factory.create_card(card_data, false)
		if card_instance:
			card_instance.set_card_data(card_data)
			card_instance.hand_manager = null  # not needed here
			card_instance.scale = Vector2(1.0, 1.0)
			card_instance.custom_minimum_size = Vector2(100, 150)

			grid_container.add_child(card_instance)

			# Connect the card's click to our "_on_card_clicked"
			card_instance.connect("gui_input", Callable(self, "_on_card_clicked").bind(card_instance))
		else:
			print("Error: Failed to create card for", card_data.name)

func _on_card_clicked(event: InputEvent, card_instance: Node):
	# We only care about left-clicks
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if this card was already highlighted
		var currently_highlighted = highlighted_cards.get(card_instance, false)

		if not currently_highlighted:
			# First left-click => highlight
			card_instance.modulate = Color(0.8, 0.8, 1)  # e.g. slight bluish highlight
			highlighted_cards[card_instance] = true
		else:
			# Second left-click on the same card => add to the deck
			if selected_deck.size() < MAX_DECK_SIZE:
				selected_deck.append(card_instance.card_data)
				print("Added to deck:", card_instance.card_data.name)

				# If you want to un-highlight it again so the user can see it "reset"
				card_instance.modulate = Color(1, 1, 1)
				highlighted_cards[card_instance] = false

				# Update the count label
				update_deck_count_label()

				# If we just hit 10, auto-confirm
				if selected_deck.size() == MAX_DECK_SIZE:
					confirm_selection()
			else:
				print("Deck is full! (10 cards)")

func update_deck_count_label():
	var deck_count_label = $Panel/DeckCountLabel
	deck_count_label.text = str(selected_deck.size()) + " / " + str(MAX_DECK_SIZE)

func confirm_selection():
	if selected_deck.size() == MAX_DECK_SIZE:
		# Store the selected deck in a global location
		var global_deck = get_node("/root/GlobalDeck")
		if global_deck:
			global_deck.player_deck = selected_deck
			print("Deck stored in GlobalDeck singleton")
		
		# Change to the main game scene
		print("Changing to main game scene")
		get_tree().change_scene_to_file("res://Scenes/Main.tscn")
	else:
		print("Please select exactly 10 cards first.")
