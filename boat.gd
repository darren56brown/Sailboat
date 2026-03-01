extends RigidBody2D

# 1. Inspector Variables
@export var wind_velocity = Vector2(200, 0)
@export var rudder_sensitivity = 2.0
@export var max_rudder_angle = 45.0
@export var rudder_efficiency = 2.0
@export var centering_speed = 2.0 

# 2. Node Hooks
@onready var rudder_pivot = $RudderPivot
@onready var rudder_arrow = $RudderForceArrow

# 3. Internal State
var rudder_angle = 0.0

func _integrate_forces(state):
	# --- 1. INPUT ---
	var turn_input = Input.get_axis("steer_right", "steer_left")
	
	# --- 2. VISUAL UPDATE (With Spring Logic) ---
	if turn_input != 0:
		rudder_angle = clamp(rudder_angle + (turn_input * rudder_sensitivity), -max_rudder_angle, max_rudder_angle)
	else:
		rudder_angle = move_toward(rudder_angle, 0, centering_speed)
	
	rudder_pivot.rotation = deg_to_rad(rudder_angle)
	
	# --- 3. RUDDER PHYSICS (LIFT MODEL) ---
	var stern_offset_local = Vector2(-24, 0) 
	var global_vel = state.linear_velocity
	var local_vel = global_vel.rotated(-rotation)
	
	# A. Get the "Face" of the rudder (The Normal Vector)
	# Vector2.UP is the side of the rudder when it's pointing East (0 deg)
	var rudder_normal_local = Vector2.UP.rotated(deg_to_rad(rudder_angle))
	
	# B. Calculate "Flow Pressure" using Dot Product
	# This measures how much the water velocity hits the flat face of the rudder
	var flow_pressure = local_vel.dot(rudder_normal_local)
	
	# C. Resulting Force (always pushes perpendicular to the rudder blade)
	# We use negative efficiency here so that 'turning right' pushes the stern 'left'
	var rudder_force_local = rudder_normal_local * flow_pressure * -rudder_efficiency
	
	# Apply force to the physics engine
	apply_force(rudder_force_local.rotated(rotation), stern_offset_local.rotated(rotation))

	# --- DRAWING THE ARROW ---
	rudder_arrow.position = stern_offset_local
	# We use a negative scale here to ensure the arrow points the direction of the "push"
	var arrow_scale = -.5 
	rudder_arrow.set_point_position(1, rudder_force_local * arrow_scale)
	
	# --- 4. HYDRODYNAMICS (Tracking) ---
	local_vel.x *= 0.99  # Forward glide
	local_vel.y *= 0.85  # Lateral resistance
	state.linear_velocity = local_vel.rotated(rotation)
	
	# --- 5. DAMPING & ENVIRONMENT ---
	state.angular_velocity *= 0.92
	apply_central_force(wind_velocity)
