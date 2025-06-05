extends Node

enum GameState {PHASE1_PREPARATION, PHASE2_COMBAT}
var current_state = GameState.PHASE1_PREPARATION
var phase1_timer = 60.0 # 60 seconds for preparation phase
var phase2_timer = 30.0 # 30 seconds for combat phase

signal phase_changed(new_phase)
signal phase2_time_updated(time_remaining)
signal phase1_time_updated(time_remaining)

func _process(delta):
	# Handle phase 1 timer
	if current_state == GameState.PHASE1_PREPARATION:
		phase1_timer -= delta
		# Prevent timer from going negative
		if phase1_timer < 0:
			phase1_timer = 0
		emit_signal("phase1_time_updated", phase1_timer)
		
		if phase1_timer <= 0:
			print("Phase 1 timer expired - transitioning to combat")
			transition_to_phase2()
			
	# Handle phase 2 timer
	elif current_state == GameState.PHASE2_COMBAT:
		phase2_timer -= delta
		# Prevent timer from going negative
		if phase2_timer < 0:
			phase2_timer = 0
		emit_signal("phase2_time_updated", phase2_timer)
		
		# Check if both sides have no creatures
		var ally_creatures = get_tree().get_nodes_in_group("ally_creatures")
		var enemy_creatures = get_tree().get_nodes_in_group("enemy_creatures")
		
		if ally_creatures.size() == 0 and enemy_creatures.size() == 0:
			print("Both sides have no creatures - transitioning to preparation phase")
			transition_to_phase1()
		# Also check if timer has expired
		elif phase2_timer <= 0:
			print("Combat time expired - transitioning to preparation phase")
			transition_to_phase1()

func transition_to_phase1():
	current_state = GameState.PHASE1_PREPARATION
	# Temporarily commenting out freeze functionality
	_freeze_all_creatures(true)
	_reset_phase1_timer()
	emit_signal("phase_changed", current_state)
	print("GAME STATE: Transitioned to Phase 1 (Preparation)")

# In GameStateManager.gd
func transition_to_phase2():
	current_state = GameState.PHASE2_COMBAT
	_unfreeze_all_creatures()  # Enable creatures for combat
	_reset_phase2_timer()
	emit_signal("phase_changed", current_state)
	print("GAME STATE: Transitioned to Phase 2 (Combat)")

func _unfreeze_all_creatures():
	var creatures = get_tree().get_nodes_in_group("ally_creatures")
	creatures.append_array(get_tree().get_nodes_in_group("enemy_creatures"))
	
	for creature in creatures:
		# Set the freeze state on the creature
		creature.is_frozen = false
		creature.can_move = true
		
		# Also unfreeze the movement system if it exists
		if creature.has_method("get") and creature.get("movement_system") != null:
			creature.movement_system.can_move = true
			
	print("All creatures unfrozen: " + str(creatures.size()) + " creatures affected")

 #Commenting out freeze functionality for now
# In GameStateManager.gd, modify the _freeze_all_creatures function
func _freeze_all_creatures(freeze: bool):
	print("FREEZE CHECK START: _freeze_all_creatures called with freeze = " + str(freeze))
	
	var ally_creatures = get_tree().get_nodes_in_group("ally_creatures")
	var enemy_creatures = get_tree().get_nodes_in_group("enemy_creatures")
	
	print("FREEZE CHECK: Found " + str(ally_creatures.size()) + " ally creatures and " + 
		  str(enemy_creatures.size()) + " enemy creatures")
	
	var creatures = []
	creatures.append_array(ally_creatures)
	creatures.append_array(enemy_creatures)
	 
	print("FREEZE CHECK: About to process " + str(creatures.size()) + " total creatures")
	
	for creature in creatures:
		# Set the freeze state on the creature
		creature.is_frozen = freeze
		
		# Only set can_move for regular creatures, not the hero
		if not creature is Hero:
			creature.can_move = !freeze
		
		print("FREEZE CHECK: Set creature " + creature.name + " is_frozen=" + str(freeze))
		 
		# Also freeze the movement system if it exists
		if creature.has_method("get") and creature.get("movement_system") != null:
			creature.movement_system.can_move = !freeze
			print("FREEZE CHECK: Also modified creature's movement system")
		else:
			print("FREEZE CHECK: Creature has no movement_system or get() method")
			
	print("FREEZE CHECK END: All creatures " + ("frozen" if freeze else "unfrozen") + 
		  ": " + str(creatures.size()) + " creatures affected")
		
		
func _reset_phase1_timer():
	phase1_timer = 60.0
	print("Phase 1 timer reset to 60 seconds")

func _reset_phase2_timer():
	phase2_timer = 30.0
	print("Phase 2 timer reset to 30 seconds")

func _check_one_side_only() -> bool:
	var ally_creatures = get_tree().get_nodes_in_group("ally_creatures")
	var enemy_creatures = get_tree().get_nodes_in_group("enemy_creatures")
	return ally_creatures.size() == 0 or enemy_creatures.size() == 0

# Always return true for now to simplify things
func is_preparation_phase() -> bool:
	return current_state == GameState.PHASE1_PREPARATION
