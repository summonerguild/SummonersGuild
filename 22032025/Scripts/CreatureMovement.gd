extends Node
class_name CreatureMovement

# Owner reference
var creature = null
var board_panel = null

# Movement parameters
var move_speed: float = 100.0
var avoidance_strength: float = 1.5
var lane_follow_strength: float = 1.2
var detection_radius: float = 80.0
var minimum_creature_distance: float = 30.0
var emergency_separation_factor: float = 5.0
var arc_curve_height: float = 50.0

# Avoidance improvements
var last_direction = Vector2.ZERO
var direction_persistence = 0.3  # How much to favor previous direction
var side_preference = 1 if randf() > 0.5 else -1  # Random side preference
var movement_priority = randf()  # Random priority between 0 and 1

# Board dimensions
var board_center_x: float = 2640
var board_width: float = 5280
var board_height: float = 780

# Lane information
var current_lane: int = 0
var lanes = {
	1: {"min_y": 70, "max_y": 300},    # Top lane
	2: {"min_y": 300, "max_y": 500},   # Middle lane
	3: {"min_y": 500, "max_y": 780}    # Bottom lane
}

# Movement state
var can_move: bool = true
var is_ally: bool = false
var target_summoner = null

func _init(owner_creature):
	creature = owner_creature
	
	# Get board panel reference without enforcing type
	if creature.get_parent():
		board_panel = creature.get_parent()
		
	# Store if creature is ally or enemy
	is_ally = creature.is_in_group("ally_creatures")
	
	# Set appropriate target summoner
	if is_ally:
		target_summoner = creature.opponent_summoner
	else:
		target_summoner = creature.opponent_summoner
		
	# Calculate board dimensions
	if board_panel:
		if board_panel is Control:
			# For Control nodes like Panel
			board_width = board_panel.size.x
			board_height = board_panel.size.y
			board_center_x = board_width / 2
		elif "size" in board_panel:
			# Handle other node types that might have size
			board_width = board_panel.size.x
			board_height = board_panel.size.y
			board_center_x = board_width / 2
			
	# Initialize with a small random direction to break symmetry
	last_direction = Vector2(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1)).normalized()

# Main movement update function - call this from _process in Creature.gd
func update_movement(delta: float) -> void:
	if not can_move or not target_summoner:
		return
	
	# Check for potential combat targets first
	if check_for_combat_targets():
		return
	
	# Identify which lane the creature is in
	current_lane = determine_lane(creature.global_position)
	
	# Calculate lane-appropriate movement
	var target_pos = get_lane_target()
	
	# Get base direction to target
	var direction = (target_pos - creature.global_position).normalized()
	
	# Apply separation from allies (avoidance)
	var separation = calculate_separation()
	
	# Combine forces with appropriate weights
	var final_direction = (direction + separation * avoidance_strength).normalized()
	
	# Mix in some of the previous direction for smooth movement
	final_direction = final_direction.lerp(last_direction, direction_persistence)
	last_direction = final_direction
	
	# Calculate new position
	var new_position = creature.global_position + final_direction * move_speed * delta
	
	# Force new position to stay within the current lane
	var lane = lanes[current_lane]
	new_position.y = clamp(new_position.y, lane["min_y"] + 10, lane["max_y"] - 10)
	
	# Apply the movement
	creature.global_position = new_position

# Determine which lane a position is in
func determine_lane(position: Vector2) -> int:
	var y_pos = position.y
	
	for lane_id in lanes:
		var lane = lanes[lane_id]
		if y_pos >= lane["min_y"] and y_pos <= lane["max_y"]:
			return lane_id
			
	# Default to middle lane if outside bounds
	return 2

# Get target position based on lane dynamics with arc movement
# In get_lane_target function, we need to modify how arc targets work
# Get target position based on lane dynamics with arc movement
# Get target position based on lane dynamics with arc movement
func get_lane_target() -> Vector2:
	# For side lanes (1 and 3), create a two-phase path
	if current_lane == 1 or current_lane == 3:
		# Get lane center Y position
		var lane_center_y = (lanes[current_lane]["min_y"] + lanes[current_lane]["max_y"]) / 2
		
		# Shield position
		var shield_pos = target_summoner.global_position if target_summoner else Vector2(board_center_x, board_height/2)
		
		# Start position (creature's current horizontal edge of screen)
		var start_x = 0 if is_ally else board_width
		var start_pos = Vector2(start_x, lane_center_y)
		
		# Mid position (center of lane)
		var mid_x = board_center_x
		var mid_pos = Vector2(mid_x, lane_center_y)
		
		# Current horizontal progress (0 = start, 1 = middle of board)
		var current_x_normalized = 0.0
		if is_ally:
			# For player creatures (going left to right)
			current_x_normalized = creature.global_position.x / board_center_x
		else:
			# For enemy creatures (going right to left)
			current_x_normalized = (board_width - creature.global_position.x) / board_center_x
		
		current_x_normalized = clamp(current_x_normalized, 0.0, 1.0)
		
		# Changed from 0.5 to 0.7 - this makes creatures start curving at 70% of the way
		var curve_threshold = 0.7
		
		# Determine if we're in first phase (moving to center) or second phase (curving to shield)
		if current_x_normalized < curve_threshold:
			# First phase: move straight toward lane center
			return mid_pos
		else:
			# Second phase: curve toward shield
			# Calculate how far we are in the second phase (0 = threshold point, 1 = end)
			var second_phase_t = (current_x_normalized - curve_threshold) / (1.0 - curve_threshold)
			
			# Start point for the curve is where we are now
			var curve_start = creature.global_position
			
			# Control point between us and shield (shifted to create a gentler curve)
			var control_x = lerp(curve_start.x, shield_pos.x, 0.5)
			var control_y = lerp(curve_start.y, shield_pos.y, 0.2) # Reduced from 0.3 to 0.2 for gentler curve
			var control_point = Vector2(control_x, control_y)
			
			# Target some distance along the curve toward the shield
			var target_t = 0.2  # Move 20% along curve each time
			
			# Calculate the target point along the curve
			var p0 = curve_start
			var p1 = control_point
			var p2 = shield_pos
			
			return quadratic_bezier(p0, p1, p2, target_t)
	else:
		# Middle lane - direct path to shield
		return target_summoner.global_position

# Quadratic Bezier curve calculation
func quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 = lerp(p0, p1, t)
	var q1 = lerp(p1, p2, t)
	return lerp(q0, q1, t)
		
func calculate_separation() -> Vector2:
	var separation_force = Vector2.ZERO
	var group_name = "ally_creatures" if is_ally else "enemy_creatures"
	
	# Find allies in detection radius
	for ally in creature.get_tree().get_nodes_in_group(group_name):
		if ally == creature:
			continue
			
		var to_ally = ally.global_position - creature.global_position
		var distance = to_ally.length()
		
		# Skip if too far
		if distance > detection_radius:
			continue
			
		# Get ally's movement system
		var ally_movement = ally.get_node_or_null("CreatureMovement")
		
		# Apply very strong force if too close (emergency separation)
		if distance < minimum_creature_distance:
			# Apply a much stronger force to prevent overlap
			var emergency_force = -to_ally.normalized() * (minimum_creature_distance / max(distance, 1.0)) * emergency_separation_factor
			
			# Apply priority system - higher priority pushes more, lower yields more
			var priority_factor = 1.0
			if ally_movement and ally_movement.movement_priority > movement_priority:
				priority_factor = 0.7  # We yield more since our priority is lower
			else:
				priority_factor = 1.3  # We push more since our priority is higher
				
			emergency_force *= priority_factor
			separation_force += emergency_force
		# Normal separation otherwise
		else:
			var away_dir = -to_ally.normalized()
			var weight = 1.0 - (distance / detection_radius)
			separation_force += away_dir * weight
	
	# Add side preference to help creatures pass on the same side consistently
	if separation_force.length_squared() > 0.01:
		var perp = Vector2(-separation_force.y, separation_force.x) * 0.15 * side_preference
		separation_force += perp
	
	# Add small random variation to break symmetry
	separation_force += Vector2(
		randf_range(-0.05, 0.05),
		randf_range(-0.05, 0.05)
	)
	
	return separation_force

# Set movement speed
func set_move_speed(speed: float) -> void:
	move_speed = speed

# Enable or disable movement
func set_can_move(can_move_value: bool) -> void:
	can_move = can_move_value

# Check for combat targets - returns true if target found
# Check for combat targets - returns true if target found
func check_for_combat_targets() -> bool:
	# Look for valid targets in attack range
	var group_to_check = "enemy_creatures" if is_ally else "ally_creatures"
	var potential_targets = creature.get_tree().get_nodes_in_group(group_to_check)
	
	for target in potential_targets:
		# Skip if the target is a spell
		if target.is_in_group("ally_spells") or target.is_in_group("enemy_spells"):
			continue
			
		var distance = creature.global_position.distance_to(target.global_position)
		if distance <= creature.attack_range:
			# Found a valid target - trigger combat mode
			creature.current_target = target
			creature.can_move = false
			can_move = false
			return true
	
	return false
	
# Helper function to find closest point on quadratic arc
func find_closest_point_on_arc(pos: Vector2, points: Array) -> float:
	var best_t = 0.0
	var closest_dist = INF
	
	# Sample the curve at different points
	for i in range(20):
		var t = i / 20.0
		var point = calculate_quadratic_point(points[0], points[1], points[2], t)
		var dist = pos.distance_to(point)
		
		if dist < closest_dist:
			closest_dist = dist
			best_t = t
	
	return best_t

# Quadratic curve interpolation (for arc path)
func calculate_quadratic_point(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	return q0.lerp(q1, t)
