extends Node

# ----------------------------------------------------------------
# Card Pool and Deck Setup
# ----------------------------------------------------------------
var card_pool = {
	"lvl0cards": [
		preload("res://CardData/lvl1 Burn synergy (1).tres"), 
		preload("res://CardData/lvl1 Burn synergy (2 ).tres"), 
		preload("res://CardData/lvl1 devilspawnwhipmaster.tres"), 
		preload("res://CardData/lvl1 Fire Elemental.tres"), 
		preload("res://CardData/lvl1 Solaris lvl1.tres"), 
		preload("res://CardData/lvl1Crimson legion .tres"), 
		preload("res://CardData/lvl1RangeBurner lvl1.tres"),
		preload("res://CardData/Spells/lvl1 Burn synergy spell.tres"),
		preload("res://CardData/Spells/Lvl 1 BuffManaRegen.tres"),
		preload("res://CardData/Spells/lvl1 Blind spell.tres"),
		preload("res://CardData/Spells/Lvl 1 Damage Spell.tres"),
		preload("res://CardData/Spells/Lvl 1 Healing Light.tres"),

	
	],
	"lvl1cards": [
		preload("res://CardData/lvl2 Burn Synergy (1).tres"),
		preload("res://CardData/lvl2 Burn Synergy (2).tres"),
		preload("res://CardData/lvl2 Crimson Legion (1).tres"), 
		preload("res://CardData/lvl2 Crimson Legion (2).tres"), 
		preload("res://CardData/lvl2 Devilspawn Cambion.tres"), 
		preload("res://CardData/Spells/Lvl 2 BuffManaTotal.tres"),
		preload("res://CardData/lvl2 Fire Elemental.tres"), 
		preload("res://CardData/lvl2 Generic Fire (2).tres"), 
		preload("res://CardData/lvl2 Generic Fire.tres"), 
		preload("res://CardData/lvl2 Ranged Fire Elemental.tres"), 
		preload("res://CardData/lvl2 Solaris.tres"),
		preload("res://CardData/Spells/Lvl 2 AOE Damage.tres"),

	],
	"lvl2cards": [
		preload("res://CardData/lvl3 Basic Fire (2).tres"),
		preload("res://CardData/lvl3 Basic Fire.tres"),
		preload("res://CardData/lvl3 Burn Synergy (1).tres"),
		preload("res://CardData/lvl3 Burn Synergy (2).tres"),
		preload("res://CardData/lvl3 Crimson Legion.tres"),
		preload("res://CardData/lvl3 Devilspawn leader (Blue).tres"),
		preload("res://CardData/lvl3 Devilspawn leader (Green.tres"),
		preload("res://CardData/lvl3 Devilspawn leader (Red).tres"),
		preload("res://CardData/lvl3 Fire elemental.tres"),
		preload("res://CardData/lvl3 Ranged Fire Elemental.tres")
	],
	"Lvl3cards": [
		preload("res://CardData/lvl4 Asmodeus.tres"),
		preload("res://CardData/lvl4 Burn synergy.tres"),
		preload("res://CardData/lvl4 Crimson Legion.tres")
	]
}
var deck = []
var is_refilling_deck = false

func create_card(card_data: carddata, is_in_fusion_menu: bool = false) -> Card:
	if card_data:
		var card_scene = preload("res://Scenes/Card.tscn").instantiate()
		card_scene.set_card_data(card_data)
		# Optionally: card_scene.is_in_fusion_menu = is_in_fusion_menu
		return card_scene
	else:
		print("Error: Card data is invalid")
		return null

func create_fusion_card() -> Card:
	if card_pool.has("lvl1cards"):
		var fusion_card_data = card_pool["lvl1cards"][0]
		return create_card(fusion_card_data, false)
	else:
		print("No 'lvl1cards' in card_pool or no data found.")
		return null

func setup_deck():
	deck.clear()
	for i in range(10):
		deck.append(card_pool["lvl0cards"][0])
	deck.shuffle()
	print("Deck initialized with %d cards." % deck.size())

func draw_card() -> Node:
	if is_refilling_deck:
		print("Cannot draw card: Deck is currently refilling.")
		return null
	if deck.size() == 0:
		print("Deck is empty. Cannot draw.")
		return null
	var card_data = deck.pop_back()
	var card_scene = create_card(card_data)
	print("Card drawn: %s. Deck size after draw: %d" % [card_data, deck.size()])
	return card_scene

func refill_deck_from_discard(discard_pile):
	if is_refilling_deck:
		print("Deck refill already in progress.")
		return
	is_refilling_deck = true
	print("Refilling deck from discard pile...")
	deck.clear()
	print("Discard pile size before refill: %d" % discard_pile.size())
	print("Discard pile being used for refill: %s" % str(discard_pile))
	deck.shuffle()
	print("Deck refilled with %d cards." % deck.size())
	print("Discard pile before clearing: %s" % str(discard_pile))
	discard_pile.clear()
	print("Discard pile cleared after refill.")
	is_refilling_deck = false

# ----------------------------------------------------------------
# Fusion Logic
# ----------------------------------------------------------------

func get_fusion_level(parent1_level: int, parent2_level: int) -> int:
	if parent1_level == parent2_level:
		return parent1_level + 1
	else:
		return max(parent1_level, parent2_level)

func similarity_score(parent1: carddata, parent2: carddata, candidate: carddata) -> float:
	var score: float = 0.0
	
	# (A) Card type check:
	if parent1.card_type == parent2.card_type:
		if candidate.card_type == parent1.card_type:
			score += 10.0
	else:
		if candidate.card_type == parent1.card_type or candidate.card_type == parent2.card_type:
			score += 5.0
			
	# (B) Archetype:
	if candidate.archetype != "":
		if candidate.archetype == parent1.archetype and candidate.archetype == parent2.archetype:
			score += 50.0
		elif candidate.archetype == parent1.archetype or candidate.archetype == parent2.archetype:
			score += 30.0
			
	# (C) Element overlap:
	score += compute_element_overlap(
		combine_parents_elements(
			convert_element_pairs_to_dict(parent1.elements),
			convert_element_pairs_to_dict(parent2.elements)
		),
		convert_element_pairs_to_dict(candidate.elements)
	)
	
	# (D) Hidden archetype:
	if candidate.hidden_archetype != "":
		if candidate.hidden_archetype == parent1.hidden_archetype or candidate.hidden_archetype == parent2.hidden_archetype:
			score += 10.0
			
	return score

# New helper function to convert element_pairs Array to Dictionary
func convert_element_pairs_to_dict(element_pairs: Array) -> Dictionary:
	var result = {}
	print("Converting element pairs: " + str(element_pairs))
	for pair in element_pairs:
		print("Processing pair: " + str(pair))
		var parts = pair.split(":")
		print("Split parts: " + str(parts))
		if parts.size() == 2:
			result[parts[0]] = float(parts[1])
			print("Added to dict: " + parts[0] + " = " + str(float(parts[1])))
	print("Conversion result: " + str(result))
	return result
func combine_parents_elements(parent1_elements: Dictionary, parent2_elements: Dictionary) -> Dictionary:
	var combined = {}
	
	# For each element in parent1, add its value.
	for elem_name in parent1_elements.keys():
		combined[elem_name] = parent1_elements[elem_name]
		
	# For each element in parent2, average if already present; otherwise, add.
	for elem_name in parent2_elements.keys():
		if combined.has(elem_name):
			combined[elem_name] = (combined[elem_name] + parent2_elements[elem_name]) / 2.0
		else:
			combined[elem_name] = parent2_elements[elem_name]
			
	return combined

func compute_element_overlap(parent_elements: Dictionary, candidate_elements: Dictionary) -> float:
	var overlap = 0.0
	for elem_name in parent_elements.keys():
		var p_val = parent_elements[elem_name]
		var c_val = candidate_elements.get(elem_name, 0.0)
		overlap += min(p_val, c_val)
		
	# Weight the overlap (adjust multiplier as desired).
	return overlap * 10.0

# --- Fusion Candidate Selection ---
func fuse_cards(parent1: carddata, parent2: carddata) -> Array:
	print("PARENT 1 ELEMENTS: ", parent1.elements)
	print("PARENT 2 ELEMENTS: ", parent2.elements)
	# 1. Determine expected fusion level.
	var result_level = get_fusion_level(parent1.fusion_level, parent2.fusion_level)
	print("Computed fusion level:", result_level)
	
	# 2. Gather all candidates with the desired fusion level.
	var possible_candidates = []
	for category in card_pool.keys():
		for candidate in card_pool[category]:
			if candidate.fusion_level == result_level:
				possible_candidates.append(candidate)
	print("Found", possible_candidates.size(), "possible candidates at fusion level", result_level)
	if possible_candidates.size() == 0:
		print("No candidates found.")
		return []
	
	# 3. Score each candidate.
	var scored = []
	for candidate in possible_candidates:
		print("CANDIDATE ELEMENTS: ", candidate.name, " - ", candidate.elements)
		var sc = similarity_score(parent1, parent2, candidate)
		scored.append({ "data": candidate, "score": sc })
		print("Scored candidate", candidate.name, "with score:", sc)
	
	# 4. Manually sort 'scored' in descending order (highest score first).
	for i in range(scored.size()):
		for j in range(i + 1, scored.size()):
			if scored[i]["score"] < scored[j]["score"]:
				var temp = scored[i]
				scored[i] = scored[j]
				scored[j] = temp
	print("Candidates sorted (descending) by score:")
	for i in range(scored.size()):
		print("  Index", i, "Candidate:", scored[i]["data"].name, "Score:", scored[i]["score"])
	
	# 5. If all candidates are tied, shuffle and pick three.
	if abs(scored[0]["score"] - scored[scored.size()-1]["score"]) < 0.000001:
		print("All candidates are tied; shuffling entire candidate list.")
		scored.shuffle()
		var final_all_tied = []
		for i in range(min(3, scored.size())):
			final_all_tied.append(scored[i]["data"])
			print("  Selected (tied):", scored[i]["data"].name)
		while final_all_tied.size() < 3:
			final_all_tied.append(scored[0]["data"])
		print("Final fusion options (all tied):")
		for candidate in final_all_tied:
			print("  ", candidate.name)
		return final_all_tied
	else:
		# 6. Otherwise, always choose the top candidate as option 1.
		var final_three = []
		final_three.append(scored[0]["data"])
		print("Option 1 chosen:", scored[0]["data"].name)
		
		# 7. Build the remainder list (all candidates except the top one).
		var remainder = scored.slice(1, scored.size() - 1)
		print("Remainder candidates count:", remainder.size())
		if remainder.size() == 0:
			print("No remainder candidates; duplicating top candidate for slots 2 and 3.")
			final_three.append(scored[0]["data"])
			final_three.append(scored[0]["data"])
		else:
			# 8. Look at the remainder's top candidate's score as the tie value.
			var tie_score = remainder[0]["score"]
			print("Tie score for remainder group:", tie_score)
			var tie_group = []
			for item in remainder:
				if abs(item["score"] - tie_score) < 0.000001:
					tie_group.append(item["data"])
				else:
					break
			print("Tie group (from remainder) size:", tie_group.size())
			if tie_group.size() >= 2:
				tie_group.shuffle()
				print("Tie group after shuffle:")
				for candidate in tie_group:
					print("  ", candidate.name)
				# Randomly choose two from the tie group.
				final_three.append(tie_group[0])
				final_three.append(tie_group[1])
				print("Option 2 chosen:", tie_group[0].name)
				print("Option 3 chosen:", tie_group[1].name)
			else:
				print("Tie group too small; using top two from remainder in order.")
				final_three.append(remainder[0]["data"])
				if remainder.size() >= 2:
					final_three.append(remainder[1]["data"])
				else:
					final_three.append(remainder[0]["data"])
		while final_three.size() > 3:
			final_three.pop_back()
		print("Final fusion options selected:")
		for candidate in final_three:
			print("  ", candidate.name)
		return final_three
