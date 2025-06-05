extends Panel

func _ready():
	# Connect the gui_input signal.
	self.connect("gui_input", Callable(self, "_on_board_panel_click_debug"))

func _on_board_panel_click_debug(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# Calculate local position manually.
		var local_pos: Vector2 = get_global_mouse_position() - global_position
		# Global position can be approximated as:
		var computed_global: Vector2 = global_position + local_pos
		print("DEBUG: BoardPanel clicked!")
		print("  Local click position: ", local_pos)
		print("  Computed global click position: ", computed_global)
