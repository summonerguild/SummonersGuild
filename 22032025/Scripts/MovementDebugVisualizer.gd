#extends Node2D
#class_name MovementDebugVisualizer
#
## Reference to the creature movement system
#var movement_system = null
#var creature = null
#
## Text display
#var debug_label: Label = null
#
## Visualization settings
#var show_debug_text: bool = true
#
## Colors
#var lane_color = Color(0.0, 0.5, 1.0, 0.3)
#var target_color = Color(1.0, 0.3, 0.3, 0.8)
#var detection_color = Color(0.2, 0.8, 0.2, 0.2)
#var direction_color = Color(1.0, 0.8, 0.2, 0.8)
#
#func _init(owner_creature, owner_movement):
	#creature = owner_creature
	#movement_system = owner_movement
	#z_index = 100
	#
	## Create debug label
	#if show_debug_text:
		#debug_label = Label.new()
		#debug_label.position = Vector2(0, -50)
		#debug_label.modulate = Color(1, 1, 1, 1)
		#debug_label.text = "Debug Active"
		#debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		#add_child(debug_label)
		#
	#print("Debug visualizer initialized for creature: ", creature.name)
#
#func _process(_delta):
	#if debug_label and movement_system:
		#var lane_info = "Unknown"
		#if movement_system.has_method("determine_lane"):
			#var lane_id = movement_system.determine_lane(creature.global_position)
			#lane_info = str(lane_id)
			#
		#debug_label.text = "Lane: " + lane_info + "\n" + \
						  #"Pos: (" + str(int(creature.global_position.x)) + ", " + \
						  #str(int(creature.global_position.y)) + ")"
	#
	#queue_redraw()
#
#func _draw():
	#if not movement_system or not creature:
		#return
	#
	## Draw detection radius
	#draw_circle(Vector2.ZERO, movement_system.detection_radius, detection_color)
	#
	## Draw movement direction
	#if movement_system.has_method("get_lane_target"):
		#var target_dir = Vector2.ZERO
		#if movement_system.is_ally:
			#target_dir = Vector2.RIGHT * 50
		#else:
			#target_dir = Vector2.LEFT * 50
			#
		#draw_line(Vector2.ZERO, target_dir, direction_color, 2)
	#
	## Only draw lane boundaries if we have lane data
	#if "lanes" in movement_system and "current_lane" in movement_system:
		#if movement_system.lanes.has(movement_system.current_lane):
			#var lane = movement_system.lanes[movement_system.current_lane]
			#if lane is Dictionary and lane.has("min_y") and lane.has("max_y"):
				#var lane_min_y = lane["min_y"] - creature.global_position.y
				#var lane_max_y = lane["max_y"] - creature.global_position.y
				#var width = 300
				#
				## Draw lane boundaries
				#draw_line(Vector2(-width, lane_min_y), Vector2(width, lane_min_y), lane_color, 2)
				#draw_line(Vector2(-width, lane_max_y), Vector2(width, lane_max_y), lane_color, 2)
