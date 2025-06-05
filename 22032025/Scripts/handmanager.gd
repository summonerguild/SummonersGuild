extends Node

const MAX_CARDS = 8
var card_list = []  # List to store the cards in the player's hand
var selected_cards = []  # To store the two cards selected for combining

var fusion_menu  # Reference to the fusion menu (to be assigned)
var card_factory  # Reference to the card factory (to be assigned)

# Track whether fusion is in progress
var is_fusion_in_progress = false

# Add a reference to the Main node
var main_node  # or var main_node: Node
var deck: Array = []



# Function to add a card to the hand
func add_card(card):
	if card_list.size() < MAX_CARDS:
		card_list.append(card)
		print("Card added! Current hand size: %d" % card_list.size())
		
		# Debug: Check if the card image is still set when added to hand
		if card.card_data and card.card_data.image:
			print("Card added to hand with image:", card.card_data.image)
		else:
			print("Card added but image missing from card_data.")

		# Center cards in hand
		if main_node:
			main_node.position_cards_centered()
		else:
			print("Error: No reference to Main node.")
	else:
		print("Hand is full! Cannot add more cards.")

# Function to remove a card and trigger re-centering of the hand
func remove_card(card):
	if card in card_list:
		card_list.erase(card)
		print("Card removed! Current hand size: %d" % card_list.size())
		
		# Re-center the hand using the reference to Main
		if main_node:
			main_node.position_cards_centered()
		else:
			print("Error: No reference to Main node.")
	else:
		print("Card not found in hand.")

# Function to highlight a card when selected
func highlight_card(card):
	# Toggle the card's highlight status
	if card.is_highlighted:
		card.toggle_highlight()  # Unhighlight the card
		if card in selected_cards:
			selected_cards.erase(card)  # Remove from selected cards
		print("Card unhighlighted. Current selected cards count:", selected_cards.size())
	else:
		if selected_cards.size() < 2:
			card.toggle_highlight()  # Highlight the card
			selected_cards.append(card)  # Add to selected cards
			print("Card highlighted. Current selected cards count:", selected_cards.size())
		else:
			print("Only two cards can be selected for combination.")

	# Open or close the fusion menu based on the number of selected cards
	if selected_cards.size() == 2:
		open_fusion_menu()  # Open fusion menu if exactly two cards are selected
		print("Fusion menu opened.")
	elif selected_cards.size() < 2:
		close_fusion_menu()  # Explicitly close the fusion menu if fewer than two cards are selected


# Function to explicitly close the fusion menu
func close_fusion_menu():
	if fusion_menu:
		fusion_menu._clear_fusion_menu()  # Call the clear function in fusionmenu.gd
		print("Fusion menu closed explicitly from handmanager.")




# Function to open the fusion menu
# In handmanager.gd
func open_fusion_menu():
	if fusion_menu:
		# We keep fusion menu visible=false until cards are created
		fusion_menu.visible = false 

		# We expect exactly 2 selected_cards here, so:
		if selected_cards.size() == 2:
			var parent1_data = selected_cards[0].card_data
			var parent2_data = selected_cards[1].card_data

			# Show a loading indicator (optional)
			# show_loading_indicator()
			
			# Start populating in the background
			fusion_menu.populate_fusion_options(parent1_data, parent2_data)
		else:
			print("Cannot populate fusion menu: need exactly two selected cards.")
	else:
		print("Error: Fusion menu not assigned.")


# Function to handle the selected fusion card
func handle_fusion_selection(fusion_card):
	print("Fusing cards into:", fusion_card.card_data.name)  # Accessing name from card_data

	# Reference the discard pile from the main node
	if main_node == null:
		print("Error: Main node reference is missing. Cannot add to discard pile.")
		return

	# Remove the two original selected cards from the hand and add to discard pile
	for card in selected_cards:
		print("Removing card from hand:", card.card_data.name)  # Access name from card_data
		remove_card(card)  # Remove from hand

		# Add the card to the discard pile in Main.gd
		print("Card added to discard pile:", card.card_data)  # Access name from card_data
		main_node.discard_pile.append(card.card_data)  # Access name from card_data


		# Ensure the card is removed from the scene and properly freed
		card.queue_free()

	# Clear the selected cards list after fusion
	selected_cards.clear()
	print("Selected cards cleared")

# Function to simulate playing a card
func play_card():
	if card_list.size() > 0:
		var played_card = card_list.pop_back()  # Remove the last card
		print("Card played: %s" % played_card.card_data.name)  # Access name from card_data
		print("Remaining hand size: %d" % card_list.size())
		return played_card
	else:
		print("No cards to play.")
		return null

# Function to get the current hand size
func get_hand_size() -> int:
	return card_list.size()

# Function to return all cards in the hand
func get_all_cards() -> Array:
	return card_list

# Method to return the number of highlighted cards
func get_highlighted_card_count() -> int:
	var count = 0
	for card in card_list:
		if card.is_highlighted:
			count += 1
	return count

# Function to get the currently highlighted card (if needed)
func get_highlighted_card() -> Card:
	for card in card_list:
		if card.is_highlighted:
			return card
	return null

# Method to remove a card from the selected list and close fusion menu if necessary
func remove_from_selected(card):
	if card in selected_cards:
		selected_cards.erase(card)
		print("Card removed from selected. Current selected cards count:", selected_cards.size())

	# Close the fusion menu if fewer than two cards are selected
	if selected_cards.size() < 2:
		close_fusion_menu()  # Explicitly close the fusion menu
