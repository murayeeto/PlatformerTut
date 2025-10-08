extends CharacterBody2D


const SPEED = 900.0
const ACCELERATION = 1200.0
const FRICTION = 1500.0
const JUMP_VELOCITY = -1000.0
const WALL_JUMP_VELOCITY = -800.0
const WALL_JUMP_PUSH = 600.0

const DASH_SPEED = 1500.0
const DASH_DURATION = 0.3
const DASH_COOLDOWN = 1.0
const AFTERIMAGE_COUNT = 5
const AFTERIMAGE_SPACING = 0.02

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO

var is_wall_sliding: bool = false
var wall_jump_timer: float = 0.0
const WALL_JUMP_TIME = 0.1

var afterimages: Array[Sprite2D] = []
var afterimage_timer: float = 0.0
const MOVEMENT_AFTERIMAGE_SPACING = 0.08
const MOVEMENT_AFTERIMAGE_SPEED_THRESHOLD = 600.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	setup_afterimages()

func setup_afterimages():
	for i in range(AFTERIMAGE_COUNT):
		var afterimage = Sprite2D.new()
		afterimage.modulate = Color(0.3, 0.6, 1.0, 0.0)  
		afterimage.z_index = -1 
		add_child(afterimage)
		afterimages.append(afterimage)

func _physics_process(delta: float) -> void:
	handle_dash_input()
	update_dash(delta)
	update_afterimages(delta)
	
	if wall_jump_timer > 0:
		wall_jump_timer -= delta
	
	check_wall_sliding()
	
	if not is_on_floor() and not is_wall_sliding:
		velocity += get_gravity() * delta
	elif is_wall_sliding:
		velocity.y += get_gravity().y * delta * 0.3
		velocity.y = min(velocity.y, 200)


	handle_jumping()


	if not is_dashing and wall_jump_timer <= 0: 
		var run_multiplier = 1
		
		if Input.is_action_pressed("run"):
			run_multiplier = 2
		else:
			run_multiplier = 1
			
		var direction := Input.get_axis("left", "right")
		var target_speed = direction * SPEED * run_multiplier
		
		if direction != 0:
			velocity.x = move_toward(velocity.x, target_speed, ACCELERATION * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		
	if velocity.x < 0:
		animated_sprite.flip_h = true
	if velocity.x > 0: 
		animated_sprite.flip_h = false
	
	if not is_dashing:
		if velocity.x != 0:
			animated_sprite.play("walk")
		else:
			animated_sprite.play("idle")
	move_and_slide()

func check_wall_sliding():
	if is_on_floor():
		is_wall_sliding = false
		return
	
	var direction = Input.get_axis("left", "right")
	is_wall_sliding = false
	
	if is_on_wall_only() and direction != 0:
		if (direction > 0 and get_wall_normal().x < 0) or (direction < 0 and get_wall_normal().x > 0):
			is_wall_sliding = true

func handle_jumping():
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			var jump_vel = JUMP_VELOCITY
			if is_dashing:
				jump_vel = JUMP_VELOCITY * 0.8
			velocity.y = jump_vel
		elif is_wall_sliding:
			var wall_normal = get_wall_normal()
			velocity.y = WALL_JUMP_VELOCITY
			velocity.x = wall_normal.x * WALL_JUMP_PUSH
			wall_jump_timer = WALL_JUMP_TIME
			is_wall_sliding = false
			
			animated_sprite.flip_h = wall_normal.x > 0

func handle_dash_input():
	if Input.is_action_just_pressed("dash") and not is_dashing and dash_cooldown_timer <= 0:
		start_dash()

func start_dash():
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	
	if animated_sprite.flip_h:
		dash_direction = Vector2.LEFT
	else:
		dash_direction = Vector2.RIGHT
	
	afterimage_timer = 0.0
	
	animated_sprite.play("walk")

func update_dash(delta):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	if not is_dashing:
		return
	
	dash_timer -= delta
	
	if dash_timer <= 0:
		is_dashing = false
		return
	
	velocity.x = dash_direction.x * DASH_SPEED

func update_afterimages(delta):
	var should_create_afterimages = false
	var spacing_to_use = AFTERIMAGE_SPACING
	
	if is_dashing:
		should_create_afterimages = true
		spacing_to_use = AFTERIMAGE_SPACING
	elif abs(velocity.x) > MOVEMENT_AFTERIMAGE_SPEED_THRESHOLD:
		should_create_afterimages = true
		spacing_to_use = MOVEMENT_AFTERIMAGE_SPACING
	
	if not should_create_afterimages:
		for afterimage in afterimages:
			if afterimage.modulate.a > 0:
				afterimage.modulate.a = lerp(afterimage.modulate.a, 0.0, delta * 8)
		return
	
	afterimage_timer += delta
	
	if afterimage_timer >= spacing_to_use:
		afterimage_timer = 0.0
		create_afterimage()

func create_afterimage():
	var target_afterimage: Sprite2D = null
	var lowest_alpha: float = 1.0
	
	for afterimage in afterimages:
		if afterimage.modulate.a < lowest_alpha:
			lowest_alpha = afterimage.modulate.a
			target_afterimage = afterimage
	
	if target_afterimage and animated_sprite.sprite_frames:
		var current_animation = animated_sprite.animation
		var current_frame = animated_sprite.frame
		
		if animated_sprite.sprite_frames.has_animation(current_animation):
			var frame_count = animated_sprite.sprite_frames.get_frame_count(current_animation)
			if current_frame < frame_count:
				var current_texture = animated_sprite.sprite_frames.get_frame_texture(current_animation, current_frame)
				
				target_afterimage.texture = current_texture
				
				var offset_distance = 50.0
				var behind_offset = Vector2.ZERO
				
				if velocity.x > 0:
					behind_offset.x = -offset_distance
				elif velocity.x < 0:
					behind_offset.x = offset_distance
				
				target_afterimage.position = animated_sprite.position + behind_offset
				target_afterimage.flip_h = animated_sprite.flip_h
				target_afterimage.scale = animated_sprite.scale
				
				if is_dashing:
					target_afterimage.modulate = Color(0.3, 0.6, 1.0, 0.6)
				else:
					target_afterimage.modulate = Color(0.3, 0.6, 1.0, 0.3)
