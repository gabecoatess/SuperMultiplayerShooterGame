extends CharacterBody3D

signal health_changed(health_value)

@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var muzzle_flash = $Camera3D/Pistol/GPUParticles3D
@onready var fire_sound = $Camera3D/Pistol/AudioStreamPlayer3D
@onready var raycast = $Camera3D/RayCast3D

var health = 100

const SPEED = 5.0
const JUMP_VELOCITY = 3.5
const CAMERA_SENSITIVITY = 0.005
const MAX_HEALTH = 100

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	if not is_multiplayer_authority(): return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * CAMERA_SENSITIVITY)
		camera.rotate_x(-event.relative.y * CAMERA_SENSITIVITY)
		
		camera.rotation.x = clamp(camera.rotation.x, -PI * 0.5, PI * 0.5)
	
	if Input.is_action_just_pressed("fire") and anim_player.current_animation != "fire":
		play_shoot_effects.rpc()
		
		if raycast.is_colliding():
			var hit_player = raycast.get_collider()
			hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	if anim_player.current_animation == "fire":
		pass
	elif input_dir != Vector2.ZERO:
		anim_player.play("move")
	else:
		anim_player.play("idle")

	move_and_slide()

@rpc("call_local")
func play_shoot_effects():
	anim_player.stop()
	anim_player.play("fire")
	muzzle_flash.restart()
	muzzle_flash.emitting = true
	fire_sound.play()

@rpc("any_peer")
func receive_damage():
	health -= 25
	
	if health <= 0:
		health = MAX_HEALTH
		position = Vector3.ZERO
	
	health_changed.emit(health)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "fire":
		anim_player.play("idle")
