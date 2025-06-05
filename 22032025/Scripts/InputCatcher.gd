extends Control

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var global_click = get_viewport().get_mouse_position()
		print("INPUTTEST: Global click at position: ", global_click)
		
		var board_panel = get_node_or_null("/root/Control/BoardPanel")
		if board_panel:
			print("INPUTTEST: BoardPanel is present!")
			print("INPUTTEST: BoardPanel global_position: ", board_panel.global_position)
			# Even though board_panel.size is (0,0), you can try to see its global rect:
			var global_rect = board_panel.get_global_rect() if board_panel.has_method("get_global_rect") else null
			if global_rect:
				print("INPUTTEST: BoardPanel global rect: ", global_rect)
			else:
				print("INPUTTEST: BoardPanel does not have a get_global_rect() method.")
			if board_panel is Control:
				print("INPUTTEST: BoardPanel size: ", board_panel.size)
			else:
				print("INPUTTEST: BoardPanel type: ", board_panel.get_class())
			
			var lane1 = board_panel.get_node_or_null("Lane1")
			if lane1:
				print("INPUTTEST: Lane1 global_position: ", lane1.global_position)
				var lane1_collision = lane1.get_node_or_null("Lane1Collision")
				if lane1_collision and lane1_collision is CollisionShape2D:
					var shape = lane1_collision.shape
					if shape is RectangleShape2D:
						print("INPUTTEST: Lane1Collision is RectangleShape2D with extents: ", shape.extents)
					elif shape is CircleShape2D:
						print("INPUTTEST: Lane1Collision is CircleShape2D with radius: ", shape.radius)
					else:
						print("INPUTTEST: Lane1Collision has shape: ", shape)
				else:
					print("INPUTTEST: Lane1Collision not found.")
			else:
				print("INPUTTEST: Lane1 not found under BoardPanel.")
		else:
			print("INPUTTEST: BoardPanel is missing!")
