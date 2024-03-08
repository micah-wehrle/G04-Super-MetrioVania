extends CharacterBody2D

# upgrades
@export var can_wall_jump = true;
@export var can_double_jump = true;
@export var can_floor_slide = true;

# Movement constants
const RUN_DECEL = 10000.0
const RUN_ACCEL = 2000.0;
const MAX_RUN_SPEED = 275.0

const JUMP_VELOCITY = -400.0

const AIR_RUN_MULT = 0.7;
const AIR_DRAG = 1000.0;
const MAX_FALL_SPEED = 500.0;

const MAX_WALL_SPEED = 100.0;
const WALL_JUMP_XVEL = 300;
const WALL_JUMP_GRACE_PERIOD = 350;
const WALL_SLIDE_MULT = 0.5;
const MAX_WALL_SLIDE_SPEED = 100.0;

const FLOOR_SLIDE_SPEED = 900.0;
const FLOOR_SLIDE_DRAG = 2000.0;
const FLOOR_SLIDE_COOLDOWN_LENGTH = 300; #ms
var last_floor_slide = 0;


const FAST_ATTACK = "Dash Attack Faster";
const FLOOR_SLIDE = "Faster Slide";

var floating = false;
var in_air = false;
var wall_sliding = false;
var floor_sliding = false;
var floor_slide_direction = 0;
const FLOAT_VEL = 100.0;

var last_on_wall = 0;
var has_double_jumped = false;

var attacking = false;

@onready var animation = %PlayerAnimationPlayer;
@onready var anim_parent = %PlayerAnimParent;
@onready var label = %Label;

var anim_text = '';

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	animation.connect("animation_finished", _animation_finished);

func _physics_process(delta):
	
	do_movement(delta);
	
	
	do_animations();
	#var fall_text = ("" if in_air else "not ") + "in air\n";
	#var vel_text = str(round(velocity.y*100)/100) + "\n";
	#var float_text = ("" if floating else "not ") + "floating\n";
	#var direction_text = str(direction) + "\n";
	#label.text = anim_text + "\n" + fall_text + float_text + vel_text + direction_text;

	move_and_slide()

func do_animations():
	if is_on_wall_only() and velocity.y > 0:
		anim("Wall Slide");
	elif !is_on_floor():
		
		if !in_air:
			in_air = true;
		
		if abs(velocity.y) < FLOAT_VEL:
			anim("Float");
			anim_text = "Float";
		elif velocity.y < 0:
			anim("Jump");
			anim_text = "Jump";
		else:
			anim("Fall");
			anim_text = "Fall";
	
	elif is_on_floor():
		if velocity.x == 0:
			anim("Idle");
		else:
			anim("Run");
		pass;

func anim(animation_name):
	if animation.current_animation == FAST_ATTACK and attacking:
		return;
	
	if animation.current_animation == FLOOR_SLIDE and floor_sliding:
		return;
	
	if animation_name != animation.current_animation:
		animation.play(animation_name);

func _animation_finished(anim_name):
	if anim_name == "Float":
		anim("Fall");
	if anim_name == FAST_ATTACK:
		attacking = false;
	if anim_name == FLOOR_SLIDE:
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
	
	var input_dir = Input.get_axis("left", "right");
	if input_dir > 0:
		input_dir = 1;
	elif input_dir < 0:
		input_dir = -1;
	
	
	if can_floor_slide and Input.is_action_just_pressed("shift key") and !floor_sliding and is_on_floor() and !is_on_wall():
		
		if input_dir and Time.get_ticks_msec() - last_floor_slide > FLOOR_SLIDE_COOLDOWN_LENGTH: # do floor slide
			do_floor_slide(input_dir);
		
	if !floor_sliding:
		if is_on_floor():
			has_double_jumped = false;
			wall_sliding = false;
			if input_dir:
				move_x(input_dir * RUN_ACCEL * delta);
			else:
				velocity.x = move_toward(velocity.x, 0, RUN_DECEL * delta);
			
			
			if Input.is_action_just_pressed("jump"):
				do_jump();
		
		elif is_on_wall_only():
			if velocity.y > 0 and get_wall_normal().x == -input_dir: # If player press into wall
				wall_sliding = true;
				velocity.y += gravity * delta * WALL_SLIDE_MULT; #TODO clamp to max wall speed!
				
				if can_wall_jump:
					has_double_jumped = false;
			
			else:
				if get_wall_normal().x == input_dir: #if player moves away from wall
					move_x(input_dir * RUN_ACCEL * delta);
				wall_sliding = false;
				velocity.y += gravity * delta;
			
			if Input.is_action_just_pressed("jump") and (can_wall_jump or (can_double_jump and !has_double_jumped)):
				if can_wall_jump:
					do_wall_jump();
				elif can_double_jump and !has_double_jumped:
					do_double_jump();
				
		else: # is in air
			wall_sliding = false;
			if input_dir:
				move_x(input_dir * RUN_ACCEL * delta * AIR_RUN_MULT);
			else:
				velocity.x = move_toward(velocity.x, 0, AIR_DRAG * delta);
			do_gravity(delta);
			
			if !has_double_jumped and Input.is_action_just_pressed("jump"):
				do_double_jump();
		
		do_gravity_clamp();
		
		if is_on_wall_only() and animation.current_animation == "Wall Slide":
			anim_parent.scale.x = -get_wall_normal().x;
		elif input_dir:
			anim_parent.scale.x = input_dir;
	else: # is floor sliding
		
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
		else:
			do_floor_slide_drag(delta);
		
		do_gravity(delta);
		do_gravity_clamp();

func move_x(accel):
	velocity.x = clamp(velocity.x + accel, -MAX_RUN_SPEED, MAX_RUN_SPEED);

func do_gravity_clamp():
	velocity.y = clamp(velocity.y, -INF, MAX_FALL_SPEED if !wall_sliding else MAX_WALL_SLIDE_SPEED);

func do_gravity(delta):
	velocity.y += gravity*delta;

func do_jump():
	velocity.y = JUMP_VELOCITY;

func do_double_jump():
	has_double_jumped = true;
	do_jump();

func do_wall_jump():
	velocity.x = WALL_JUMP_XVEL * get_wall_normal().x;
	do_jump();

func do_floor_slide_drag(delta):
	velocity.x = move_toward(velocity.x, 0, FLOOR_SLIDE_DRAG * delta);

func do_floor_slide(input_dir):
	last_floor_slide = INF; 
	floor_sliding = true;
	anim(FLOOR_SLIDE);
	velocity.x = input_dir * FLOOR_SLIDE_SPEED;

func end_floor_slide():
	last_floor_slide = Time.get_ticks_msec();
	floor_sliding = false;
