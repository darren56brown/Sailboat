extends Line2D

@export var target_path: NodePath # We will pick the boat here
@export var max_points = 100     # How long the trail is

@onready var target = get_node(target_path)

var total_delta = 0

func _physics_process(_delta):
	total_delta += _delta
	if total_delta < .075:
		return
	
	total_delta = 0
	var pos = target.global_position
	
	add_point(pos)
	
	if points.size() > max_points:
		remove_point(0)
