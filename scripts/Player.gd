extends CharacterBody2D

# upgrades
@export var can_wall_jump = true;
@export var can_double_jump = true;
@export var can_floor_slide = true;

# Movement constants
const RUN_DECEL = 10000.0
const RUN_ACCEL = 2000.0;
const MAX_RUN_SPEED = 275.0

# Jumping
const JUMP_VELOCITY = -400.0
const MAX_FALL_SPEED = 500.0;
const FLOAT_VEL = 100.0;

# Airborne movement
const AIR_RUN_MULT = 0.7;
const AIR_DRAG = 1000.0;

# Wall movement
const MAX_WALL_SPEED = 100.0;
const WALL_JUMP_XVEL = 300;
const WALL_JUMP_GRACE_PERIOD = 350;
const WALL_SLIDE_MULT = 0.5;
const MAX_WALL_SLIDE_SPEED = 100.0;

# Floor slide
const FLOOR_SLIDE_SPEED = 900.0;
const FLOOR_SLIDE_DRAG = 2000.0;
const FLOOR_SLIDE_COOLDOWN_LENGTH = 300; #ms

# Animation names - TODO: use enum
const FAST_ATTACK = "Dash Attack Faster";
const FLOOR_SLIDE = "Faster Slide";

# Action monitors
var wall_sliding = false;
var floor_sliding = false;
var floor_slide_direction = 0;
var last_floor_slide = 0;
var has_double_jumped = false;
var attacking = false;

@onready var animation = %PlayerAnimationPlayer;
@onready var anim_parent = %PlayerAnimParent;
@onready var label = %Label;

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	animation.connect("animation_finished", _animation_finished);

func _physics_process(delta):
	
	do_movement(delta);
	do_animations();

	move_and_slide()

func do_animations():
	# If player is against a wall and falling down, wall slide
	if is_on_wall_only() and velocity.y > 0: 
		anim("Wall Slide");
	
	# If player is in the air
	elif !is_on_floor(): 
		if abs(velocity.y) < FLOAT_VEL:
			anim("Float");
		elif velocity.y < 0:
			anim("Jump");
		else:
			anim("Fall");
	
	# If player is on the floor
	elif is_on_floor():
		if velocity.x == 0:
			anim("Idle");
		else:
			anim("Run");
		pass;

func anim(animation_name):
	# Don't allow for animation change during an attack
	if animation.current_animation == FAST_ATTACK and attacking:
		return;
	
	# Don't allow for animation change during a floor slide
	if animation.current_animation == FLOOR_SLIDE and floor_sliding:
		return;
	
	# Only start an animation if calling for a new animation
	if animation_name != animation.current_animation:
		animation.play(animation_name);

func _animation_finished(anim_name):
	if anim_name == "Float": # Switch to fall animation after float finishes
		anim("Fall");
	if anim_name == FAST_ATTACK: # Turn off attacking state when attack animation finishes
		attacking = false;
	if anim_name == FLOOR_SLIDE: # End floor slide when animation finishes
		end_floor_slide();

"""
logic for movement:
	
	is on floor:
		run/slide
		can jump
		reset double jump
	is on wall only:
		if going up and can double jump:
			can wall jump
		if going down:
			reset double jump
			can wall jump
	is in air:
		can double jump 
	
"""

func do_movement(delta):
	
	# Read left/right input and ensure it's only -1, 0, or 1 (for analog controllers)
	var input_dir = Input.get_axis("left", "right");
	if input_dir > 0:
		input_dir = 1;
	elif input_dir < 0:
		input_dir = -1;
	
	# Check for floor slide conditions. Put this first so player can't press floor slide button and antother input the same frame
	if can_floor_slide and Input.is_action_just_pressed("shift key"):
		if !floor_sliding and is_on_floor() and !is_on_wall() and input_dir:
			if Time.get_ticks_msec() - last_floor_slide > FLOOR_SLIDE_COOLDOWN_LENGTH: # stacked like this for readability
				do_floor_slide(input_dir);
	
	# If the player isn't locked out of control due to a floor slide:
	if !floor_sliding:
		
		# Floor-based controls:
		if is_on_floor():
			has_double_jumped = false;
			wall_sliding = false;
			
			if input_dir: # Move player
				move_x(input_dir * RUN_ACCEL * delta);
			else: # Slow player
				velocity.x = move_toward(velocity.x, 0, RUN_DECEL * delta);
			
			
			if Input.is_action_just_pressed("jump"):
				do_jump();
		
		# Wall-based controls
		elif is_on_wall_only():
			if velocity.y > 0 and get_wall_normal().x == -input_dir: # If player press into wall
				wall_sliding = true;
				do_wall_gravity(delta);
				
				if can_wall_jump and can_double_jump: # Only reset double jump ability while on a wall if the player can also wall jump. Otherwise double jump allows for wall jumping
					has_double_jumped = false;
			
			else:
				if get_wall_normal().x == input_dir: #if player moves away from wall
					move_x(input_dir * RUN_ACCEL * delta);
				wall_sliding = false;
				velocity.y += gravity * delta;
			
			# Allows player to either wall jump, or double jump while on a wall if they can't wall jump and have the ability to double jump.
			if Input.is_action_just_pressed("jump") and (can_wall_jump or (can_double_jump and !has_double_jumped)):
				if can_wall_jump:
					do_wall_jump();
				elif can_double_jump and !has_double_jumped:
					do_double_jump();
		
		# Air-based controls
		else:
			wall_sliding = false;
			
			if input_dir: # Move player in air
				move_x(input_dir * RUN_ACCEL * delta * AIR_RUN_MULT);
			else:
				velocity.x = move_toward(velocity.x, 0, AIR_DRAG * delta);
			
			do_gravity(delta);
			
			if !has_double_jumped and Input.is_action_just_pressed("jump"):
				do_double_jump();
		
		do_gravity_clamp();
		
		# Mirror player sprite based on direction or if wall sliding
		if is_on_wall_only() and animation.current_animation == "Wall Slide":
			anim_parent.scale.x = -get_wall_normal().x;
		elif input_dir:
			anim_parent.scale.x = input_dir;
	
	# If the player is actively floor sliding
	else:
		# Allows for player to jump out of a floor slide early
		if Input.is_action_just_pressed("jump"):
			var did_jump = false;
			if is_on_floor():
				did_jump = true;
				do_jump();
			elif !is_on_wall() and !has_double_jumped:
				did_jump = true;
				do_double_jump();
			
			if did_jump:
				end_floor_slide();
		
		#if not floor sliding:
		else:
			do_floor_slide_drag(delta);
		
		do_gravity(delta);
		do_gravity_clamp();

func move_x(accel): # Applies movement acceleration for side-to-side movement
	velocity.x = clamp(velocity.x + accel, -MAX_RUN_SPEED, MAX_RUN_SPEED);

func do_gravity_clamp(): # Clamps fall speed to terminal velocity, or slower for wall sliding
	velocity.y = clamp(velocity.y, -INF, MAX_FALL_SPEED if !wall_sliding else MAX_WALL_SLIDE_SPEED);

func do_gravity(delta): # Applies gravity
	velocity.y += gravity * delta;

func do_wall_gravity(delta):
	velocity.y += gravity * delta * WALL_SLIDE_MULT;

func do_jump(): # Sets upwards jump velocity
	velocity.y = JUMP_VELOCITY;

func do_double_jump(): # Sets upwards jump velocity for double jump
	has_double_jumped = true;
	do_jump();

func do_wall_jump(): # Sets horizontal jump velocity and upwards jump velocity for wall jump
	velocity.x = WALL_JUMP_XVEL * get_wall_normal().x;
	do_jump();

func do_floor_slide_drag(delta): # Slows floor slide down during the slide
	velocity.x = move_toward(velocity.x, 0, FLOOR_SLIDE_DRAG * delta);

func do_floor_slide(input_dir): # sets floor slide velocity and starts animation
	last_floor_slide = INF; 
	floor_sliding = true;
	anim(FLOOR_SLIDE);
	velocity.x = input_dir * FLOOR_SLIDE_SPEED;

func end_floor_slide(): # Stops slide and logs end of slide time
	last_floor_slide = Time.get_ticks_msec();
	floor_sliding = false;
