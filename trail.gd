extends Line2D

@export var target_path: NodePath # We will pick the boat here
@export var max_points = 100     # How long the trail is

@onready var target = get_node(target_path)

func _process(_delta):
	# 1. Get the boat's current global position
	var pos = target.global_position
	
	# 2. Add the new point to the line
	add_point(pos)
	
	# 3. If the trail is too long, remove the oldest point
	if points.size() > max_points:
		remove_point(0)
