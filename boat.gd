extends RigidBody2D

@export var wind_velocity = Vector2(200, 0)
@export var rudder_rate_deg_per_frame = 120.0
@export var max_rudder_angle_deg = 60.0
@export var rudder_efficiency = 2.0

@onready var rudder_pivot = $RudderPivot
@onready var rudder_arrow = $RudderForceArrow

var rudder_angle_deg = 0.0
var is_centering: bool = false
var rudder_force_local = Vector2()
var rudder_center_local = Vector2()

#Computed as often as possible. Use for graphics updates and to recore from UI
func _process(delta: float):
	#Compute is centering state from key states
	if (Input.is_action_pressed("steer_left") ||
		Input.is_action_pressed("steer_right")):
		is_centering = false
	elif Input.is_action_just_pressed("center_rudder"):
		is_centering = !is_centering
		
	#Update rudder graphics to match angle
	rudder_pivot.rotation = deg_to_rad(rudder_angle_deg)
	
	#Update rudder force arrow graphics
	rudder_arrow.position = rudder_center_local
	rudder_arrow.set_point_position(1, rudder_force_local * -0.5)
	
#Computed every physics tick. Do everything here except set state varaibles
func _physics_process(delta: float):
	#Turn off centering if we are already near 0 degrees
	if is_equal_approx(rotation_degrees, 0):
		is_centering = false	
		
	#Don't use built in physics model for rudder angle
	if is_centering:
		rudder_angle_deg = move_toward(rudder_angle_deg, 0, rudder_rate_deg_per_frame * delta)
	else:
		var turn_input = Input.get_axis("steer_right", "steer_left")
		if turn_input != 0:
			rudder_angle_deg = clamp(rudder_angle_deg + (turn_input * rudder_rate_deg_per_frame * delta),
				-max_rudder_angle_deg, max_rudder_angle_deg)
		
#Also computed every physics tick. Update state variables here
func _integrate_forces(state):
	var stern_offset_local = Vector2(-18, 0) # The hinge point
	var rudder_length = 10.0                 # The length of your rudder blade
	var center_offset = rudder_length / 2.0  # Center of pressure is halfway
	
	# Calculate where the MIDDLE of the rudder is in boat-local space
	var rudder_dir_local = Vector2.RIGHT.rotated(deg_to_rad(rudder_angle_deg))
	rudder_center_local = stern_offset_local - (rudder_dir_local * center_offset)
	
	var global_vel = state.linear_velocity
	var local_vel = global_vel.rotated(-rotation)
	
	# A. Get the "Face" (Normal) of the rudder
	var rudder_normal_local = Vector2.UP.rotated(deg_to_rad(rudder_angle_deg))
	
	# B. Calculate Pressure
	var flow_pressure = local_vel.dot(rudder_normal_local)
	
	# C. Resulting Force
	rudder_force_local = rudder_normal_local * flow_pressure * -rudder_efficiency
	
	# Apply force at the ACTUAL CENTER of the rudder, not the hinge
	# We rotate the local center point into global space
	var force_pos_global = rudder_center_local.rotated(rotation)
	apply_force(rudder_force_local.rotated(rotation), force_pos_global)

	# --- 4. HYDRODYNAMICS (Tracking) ---
	local_vel.x *= 0.99  # Forward glide
	local_vel.y *= 0.85  # Lateral resistance
	state.linear_velocity = local_vel.rotated(rotation)
	
	# --- 5. DAMPING & ENVIRONMENT ---
	state.angular_velocity *= 0.92
	apply_central_force(wind_velocity)
