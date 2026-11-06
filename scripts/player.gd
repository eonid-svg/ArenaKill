extends CharacterBody3D
## First-person player controller with dash + slam movement.

const MOVE_SPEED := 9.0
const JUMP_VELOCITY := 5.5
const MOUSE_SENS := 0.003
const ACCEL_GROUND := 16.0
const ACCEL_AIR := 5.0

const DASH_SPEED := 24.0
const DASH_DURATION := 0.15
const DASH_COOLDOWN := 0.7

const SLAM_SPEED := 32.0
const SLAM_COOLDOWN := 0.6

const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12

const DASH_SND := preload("res://assets/sounds/dash.wav")
const SLAM_SND := preload("res://assets/sounds/slam.wav")
const JUMP_SND := preload("res://assets/sounds/jump.wav")
const LAND_SND := preload("res://assets/sounds/land.wav")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var camera: Camera3D
var body_mesh: MeshInstance3D
var body_mat: StandardMaterial3D

var dash_timer := 0.0
var dash_cd := 0.0
var dash_dir := Vector3.ZERO

var slamming := false
var slam_cd := 0.0

var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var was_on_floor := true

var snd_dash: AudioStreamPlayer3D
var snd_slam: AudioStreamPlayer3D
var snd_jump: AudioStreamPlayer3D
var snd_land: AudioStreamPlayer3D


func _init() -> void:
	_build_body()


func _ready() -> void:
	_apply_authority_visuals()
	if is_multiplayer_authority() and not DisplayServer.get_name() == "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Build the whole body in _init (NOT _ready) so that when a player is
## replicated to clients by MultiplayerSpawner, each peer builds the body
## exactly once and nothing gets duplicated.
func _build_body() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

	camera = Camera3D.new()
	camera.position = Vector3(0, 0.9, 0)
	add_child(camera)

	body_mesh = MeshInstance3D.new()
	var cap_mesh := CapsuleMesh.new()
	cap_mesh.radius = 0.35
	cap_mesh.height = 1.8
	body_mat = StandardMaterial3D.new()
	body_mat.metallic = 0.3
	body_mat.roughness = 0.25
	body_mat.emission_enabled = true
	body_mat.emission_energy_multiplier = 1.5
	cap_mesh.material = body_mat
	body_mesh.mesh = cap_mesh
	body_mesh.position = Vector3(0, 0.9, 0)
	add_child(body_mesh)

	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	add_child(sync)
	var rep := SceneReplicationConfig.new()
	rep.add_property(NodePath(":position"))
	rep.add_property(NodePath(":rotation"))
	sync.replication_config = rep

	snd_dash = _make_snd(DASH_SND)
	snd_slam = _make_snd(SLAM_SND)
	snd_jump = _make_snd(JUMP_SND)
	snd_land = _make_snd(LAND_SND)


func _apply_authority_visuals() -> void:
	camera.current = is_multiplayer_authority()
	if is_multiplayer_authority():
		body_mat.albedo_color = Color(0.05, 0.5, 0.6)
		body_mat.emission = Color(0.0, 0.9, 1.0)
	else:
		body_mat.albedo_color = Color(0.6, 0.3, 0.05)
		body_mat.emission = Color(1.0, 0.5, 0.0)


func _make_snd(stream: AudioStream) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.unit_size = 6.0
	add_child(p)
	return p


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if dash_cd > 0.0:
		dash_cd -= delta
	if slam_cd > 0.0:
		slam_cd -= delta

	if is_on_floor():
		coyote_timer = COYOTE_TIME
	elif coyote_timer > 0.0:
		coyote_timer -= delta

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER
	elif jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if Input.is_action_just_pressed("dash") and dash_cd <= 0.0:
		dash_timer = DASH_DURATION
		dash_cd = DASH_COOLDOWN
		dash_dir = dir if dir != Vector3.ZERO else -transform.basis.z
		dash_dir.y = 0.0
		dash_dir = dash_dir.normalized()
		snd_dash.play()

	if Input.is_action_just_pressed("slam") and not is_on_floor() and slam_cd <= 0.0:
		slamming = true
		slam_cd = SLAM_COOLDOWN

	if dash_timer > 0.0:
		dash_timer -= delta
		velocity = dash_dir * DASH_SPEED
		velocity.y = 0.0
	elif slamming:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -SLAM_SPEED
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta

		if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
			velocity.y = JUMP_VELOCITY
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			snd_jump.play()

		var speed := MOVE_SPEED
		var accel := ACCEL_GROUND if is_on_floor() else ACCEL_AIR
		var target := dir * speed
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)

	move_and_slide()

	if slamming and is_on_floor():
		slamming = false
		_do_slam_impact()

	if not was_on_floor and is_on_floor():
		snd_land.play()
	was_on_floor = is_on_floor()


func _do_slam_impact() -> void:
	snd_slam.play()
	# Future: AoE damage + screen shake hook.


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clampf(camera.rotation.x, -1.5, 1.5)
