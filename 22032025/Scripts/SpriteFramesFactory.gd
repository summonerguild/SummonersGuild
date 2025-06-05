# SpriteFramesFactory.gd
extends Node

# Create a basic SpriteFrames with default animation
static func create_basic_frames(base_texture: Texture2D) -> SpriteFrames:
	var frames = SpriteFrames.new()
	
	# Add default animation
	if !frames.has_animation("default"):
		frames.add_animation("default")
		frames.set_animation_loop("default", true)
		frames.set_animation_speed("default", 5)
	
	# Clear any existing frames
	var frame_count = frames.get_frame_count("default")
	for i in range(frame_count):
		frames.remove_frame("default", 0)
		
	# Add the base texture as the only frame
	frames.add_frame("default", base_texture)
	
	# Add idle animation (same as default for now)
	if !frames.has_animation("idle"):
		frames.add_animation("idle")
		frames.set_animation_loop("idle", true)
		frames.set_animation_speed("idle", 5)
		frames.add_frame("idle", base_texture)
	
	return frames

# Add directional frames for a specific creature
static func add_directional_frames(frames: SpriteFrames, east_texture: Texture2D, directions: Array = ["e"]):
	# Add each requested direction
	for dir in directions:
		var anim_name = "move_" + dir
		
		# Add the animation if it doesn't exist
		if !frames.has_animation(anim_name):
			frames.add_animation(anim_name)
			frames.set_animation_loop(anim_name, true)
			frames.set_animation_speed(anim_name, 5)
			
		# Clear existing frames
		var frame_count = frames.get_frame_count(anim_name)
		for i in range(frame_count):
			frames.remove_frame(anim_name, 0)
		
		# Add texture as frame
		if dir == "e":
			frames.add_frame(anim_name, east_texture)
		else:
			# For other directions, we'll need to add those textures later
			# For now, just use east as placeholder
			frames.add_frame(anim_name, east_texture)
	
	return frames# In SpriteFramesFactory.gd or another appropriate place:
func add_east_animation(frames, east_texture):
	var anim_name = "move_e"
	
	# Add the animation if it doesn't exist
	if !frames.has_animation(anim_name):
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, true)
		frames.set_animation_speed(anim_name, 5)
	
	# Clear existing frames
	var frame_count = frames.get_frame_count(anim_name)
	for i in range(frame_count):
		frames.remove_frame(anim_name, 0)
	
	# Add east texture as frame
	frames.add_frame(anim_name, east_texture)
	
	return frames
