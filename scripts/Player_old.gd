extends CharacterBody2D

# upgrades
var can_wall_jump = true;
var can_double_jump = true;


const RUN_DECEL = 300.0
const RUN_ACCEL = 50.0;
const MAX_RUN_SPEED = 275.0
const JUMP_VELOCITY = -400.0
const WALL_JUMP_XVEL = 200;
const AIR_DRAG = 0.9;
const MAX_WALL_SPEED = 100.0;
const AIR_RUN_MULT = 0.7;
const WALL_JUMP_GRACE_PERIOD = 350;
const FLOOR_SLIDE_SPEED = 900.0;

const FAST_ATTACK = "Dash Attack Faster";

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
	
	do_movement_old(delta);
	
	
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
	
	if animation.current_animation == "Slide" and floor_sliding:
		return;
	
	if animation_name != animation.current_animation:
		animation.play(animation_name);

func _animation_finished(anim_name):
	if anim_name == "Float":
		anim("Fall");
	if anim_name == FAST_ATTACK:
		attacking = false;
	if anim_name == "Slide":
		floor_sliding = false;

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

func do_movement_old(delta):
	var direction = Input.get_axis("left", "right") if !floor_sliding else floor_slide_direction;
	if direction:
		var facing = direction;
		#if is_on_wall_only() and attacking:
		#	facing = -facing;
		
		if !attacking:
			anim_parent.scale = Vector2(facing, 1);
		
		velocity.x = move_toward(velocity.x, MAX_RUN_SPEED*direction, RUN_ACCEL * (AIR_RUN_MULT if !is_on_floor() else 1));
		
	else:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, RUN_DECEL);
	
	
	if not is_on_floor():
		velocity.x *= AIR_DRAG;
		velocity.y += gravity * delta;
		if is_on_wall() and get_wall_normal().x == -direction and velocity.y > 0 and !attacking:
			wall_sliding = true;
			velocity.y = clamp(velocity.y, 0, MAX_WALL_SPEED);
		elif wall_sliding:
			last_on_wall = Time.get_ticks_msec();
			wall_sliding = false;
	
	if has_double_jumped and (is_on_floor() or (can_wall_jump and wall_sliding)):
		has_double_jumped = false;
	
	# Handle Jump.
	if Input.is_action_just_pressed("jump") and !floor_sliding:
		if is_on_floor():
			velocity.y = JUMP_VELOCITY;
		elif can_wall_jump and (wall_sliding or Time.get_ticks_msec() - last_on_wall < WALL_JUMP_GRACE_PERIOD):
			velocity.y = JUMP_VELOCITY;
			velocity.x = get_wall_normal().x * WALL_JUMP_XVEL;
		elif can_double_jump and !has_double_jumped:
			has_double_jumped = true;
			velocity.y = JUMP_VELOCITY;
	
	if Input.is_action_just_pressed("enter") and !attacking and !floor_sliding:
		anim(FAST_ATTACK);
		attacking = true;
	
	if Input.is_action_just_pressed("shift key") and !floor_sliding and !attacking:
		if is_on_floor() and direction and abs(velocity.x) > 10 and !attacking and velocity.y == 0:
			floor_sliding = true;
			floor_slide_direction = direction;
			velocity.x = FLOOR_SLIDE_SPEED * direction;
			anim("Slide");
	









