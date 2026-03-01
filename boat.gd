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
	
		# --- 3. RUDDER PHYSICS (LEVER MODEL) ---
	var stern_offset_local = Vector2(-18, 0) # The hinge point
	var rudder_length = 10.0                 # The length of your rudder blade
	var center_offset = rudder_length / 2.0  # Center of pressure is halfway
	
	# Calculate where the MIDDLE of the rudder is in boat-local space
	var rudder_dir_local = Vector2.RIGHT.rotated(deg_to_rad(rudder_angle))
	var rudder_center_local = stern_offset_local - (rudder_dir_local * center_offset)
	
	var global_vel = state.linear_velocity
	var local_vel = global_vel.rotated(-rotation)
	
	# A. Get the "Face" (Normal) of the rudder
	var rudder_normal_local = Vector2.UP.rotated(deg_to_rad(rudder_angle))
	
	# B. Calculate Pressure
	var flow_pressure = local_vel.dot(rudder_normal_local)
	
	# C. Resulting Force
	var rudder_force_local = rudder_normal_local * flow_pressure * -rudder_efficiency
	
	# Apply force at the ACTUAL CENTER of the rudder, not the hinge
	# We rotate the local center point into global space
	var force_pos_global = rudder_center_local.rotated(rotation)
	apply_force(rudder_force_local.rotated(rotation), force_pos_global)

	# --- 4. UPDATE THE DEBUG ARROW ---
	# Move the arrow's start to the center of the rudder blade
	rudder_arrow.position = rudder_center_local
	rudder_arrow.set_point_position(1, rudder_force_local * -0.5)
	
	# --- 4. HYDRODYNAMICS (Tracking) ---
	local_vel.x *= 0.99  # Forward glide
	local_vel.y *= 0.85  # Lateral resistance
	state.linear_velocity = local_vel.rotated(rotation)
	
	# --- 5. DAMPING & ENVIRONMENT ---
	state.angular_velocity *= 0.92
	apply_central_force(wind_velocity)
