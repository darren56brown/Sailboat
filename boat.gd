extends RigidBody2D

@export var wind_velocity = Vector2(200, 0)
@export var rudder_rotation_rate = 100.0 #deg/sec
@export var max_rudder_angle_deg = 45.0
@export var rudder_efficiency = 2.0
@export var rudder_hinge_position = Vector2(-18, 0)
@export var drag_center_position = Vector2(-2, 0) #Drag a bit behind the cg
@export var rudder_length = 10
@export var water_velocity = Vector2(0, 0)
@export var hull_drag = 8.0

#How many times harder to push sideways? This causes physics
#to go unstable at values over 10 for some reason
@export var hull_drag_ratio = 8.0 

@onready var rudder_pivot = $RudderPivot
@onready var rudder_arrow = $RudderForceArrow
@onready var drag_arrow = $DragForceArrow

var rudder_angle_deg = 0.0
var is_centering: bool = false
var rudder_force = Vector2()
var drag_force = Vector2()
var rudder_center_position = Vector2()

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
	rudder_arrow.position = rudder_center_position
	rudder_arrow.set_point_position(1, rudder_force * -0.25)
	
	drag_arrow.position = drag_center_position
	drag_arrow.set_point_position(1, drag_force * -0.25)
	
#Computed every physics tick. Do everything here except set state varaibles
func _physics_process(delta: float):
	#Turn off centering if we are already near 0 degrees
	if is_equal_approx(rotation_degrees, 0):
		is_centering = false	
		
	#Don't use built in physics model for rudder angle
	if is_centering:
		rudder_angle_deg = move_toward(rudder_angle_deg, 0, rudder_rotation_rate * delta)
	else:
		var turn_input = Input.get_axis("steer_right", "steer_left")
		if turn_input != 0:
			rudder_angle_deg = clamp(rudder_angle_deg + (turn_input * rudder_rotation_rate * delta),
				-max_rudder_angle_deg, max_rudder_angle_deg)
				
	var rudder_unit_vec = Vector2.LEFT.rotated(deg_to_rad(rudder_angle_deg))
	rudder_center_position = rudder_hinge_position + rudder_unit_vec * rudder_length / 2.0
		
#Also computed every physics tick. Update state variables here
func _integrate_forces(state):
	var flow_velocity = (state.linear_velocity.rotated(-rotation) -
		water_velocity.rotated(-rotation))
	
	#rudder force
	var rudder_unit_normal = Vector2.UP.rotated(deg_to_rad(rudder_angle_deg))
	var rudder_normal_velocity = rudder_unit_normal * flow_velocity.dot(rudder_unit_normal)
	rudder_force = rudder_normal_velocity * -rudder_efficiency
	apply_force(rudder_force.rotated(rotation),
		rudder_center_position.rotated(rotation))

	#drag force
	drag_force.x = flow_velocity.x * -hull_drag
	drag_force.y = flow_velocity.y * -hull_drag * hull_drag_ratio
	apply_force(drag_force.rotated(rotation),
		drag_center_position.rotated(rotation))
	
	#drag torque
	apply_torque(state.angular_velocity * -1000)
	
	#wind force
	apply_central_force(wind_velocity)
