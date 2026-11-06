extends CharacterBody3D
## First-person player controller.
## Movement is applied only on the peer that owns this player
## (is_multiplayer_authority()); remote peers read the synced transform
## via the MultiplayerSynchronizer added in _build_body().

const WALK_SPEED := 6.0
const SPRINT_SPEED := 10.5
const JUMP_VELOCITY := 5.5
const MOUSE_SENS := 0.003
const ACCEL_GROUND := 14.0
const ACCEL_AIR := 4.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var camera: Camera3D


func _ready() -> void:
	_build_body()


## Build collision, camera, a visible mesh and the network synchronizer
## procedurally so the .tscn stays tiny.
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
	camera.current = is_multiplayer_authority()
	add_child(camera)

	var mesh := MeshInstance3D.new()
	var cap_mesh := CapsuleMesh.new()
	cap_mesh.radius = 0.35
	cap_mesh.height = 1.8
	mesh.mesh = cap_mesh
	mesh.position = Vector3(0, 0.9, 0)
	add_child(mesh)

	# Replicate position/rotation to other peers.
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	add_child(sync)
	var rep := SceneReplicationConfig.new()
	rep.add_property(NodePath(":position"))
	rep.add_property(NodePath(":rotation"))
	sync.replication_config = rep

	if is_multiplayer_authority() and not DisplayServer.get_name() == "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var accel := ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	var target := dir * speed

	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clampf(camera.rotation.x, -1.5, 1.5)
