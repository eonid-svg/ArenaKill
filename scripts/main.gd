extends Node3D
## Main scene + network manager.
##
## Usage (user args after `--`):
##   godot --path . -- --host            # start a LAN server
##   godot --path . -- --join 1.2.3.4    # join a server at 1.2.3.4
## With no args, defaults to hosting so a lone run just works.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const DEFAULT_PORT := 7000

const ARENA_HALF := 20.0
const WALL_HEIGHT := 4.0

var players: Node3D
var spawner: MultiplayerSpawner


func _ready() -> void:
	_build_arena()
	_setup_networking()


func _setup_networking() -> void:
	players = Node3D.new()
	players.name = "Players"
	add_child(players)

	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	spawner.spawn_function = _spawn_player
	add_child(spawner)
	spawner.spawn_path = players.get_path()

	var args := OS.get_cmdline_user_args()
	var is_host := false
	var join_ip := ""
	for i in args.size():
		if args[i] == "--host":
			is_host = true
		elif args[i] == "--join" and i + 1 < args.size():
			join_ip = args[i + 1]

	if is_host:
		_start_host(DEFAULT_PORT)
	elif join_ip != "":
		_start_client(join_ip, DEFAULT_PORT)
	else:
		_start_host(DEFAULT_PORT)


func _start_host(port: int) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		push_error("Failed to create server on port %d: %s" % [port, err])
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("[net] hosting on port %d" % port)
	_on_peer_connected(1)  # spawn the host's own player


func _start_client(ip: String, port: int) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		push_error("Failed to connect to %s:%d: %s" % [ip, port, err])
		return
	multiplayer.multiplayer_peer = peer
	print("[net] connecting to %s:%d" % [ip, port])


func _on_peer_connected(peer_id: int) -> void:
	print("[net] peer %d connected — spawning player" % peer_id)
	spawner.spawn(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	var node := players.get_node_or_null(str(peer_id))
	if node:
		node.queue_free()


func _spawn_player(data) -> Node:
	var p := PLAYER_SCENE.instantiate()
	p.name = str(data)
	p.set_multiplayer_authority(data)
	p.position = _random_spawn_point()
	return p


func _random_spawn_point() -> Vector3:
	var r := ARENA_HALF * 0.7
	return Vector3(randf_range(-r, r), 1.0, randf_range(-r, r))


func _build_arena() -> void:
	# Transparent (see-through) floor.
	_add_box(Vector3(0, -0.5, 0), Vector3(ARENA_HALF * 2, 1, ARENA_HALF * 2), Color(0.2, 0.2, 0.25, 0.4), true)

	# Two black walls (along Z axis).
	var black := Color(0.05, 0.05, 0.06)
	var wall_size := Vector3(ARENA_HALF * 2, WALL_HEIGHT, 1)
	_add_box(Vector3(0, WALL_HEIGHT * 0.5, -ARENA_HALF - 0.5), wall_size, black)
	_add_box(Vector3(0, WALL_HEIGHT * 0.5, ARENA_HALF + 0.5), wall_size, black)

	# Two grey walls (along X axis).
	var grey := Color(0.55, 0.55, 0.6)
	var wall_side := Vector3(1, WALL_HEIGHT, ARENA_HALF * 2)
	_add_box(Vector3(-ARENA_HALF - 0.5, WALL_HEIGHT * 0.5, 0), wall_side, grey)
	_add_box(Vector3(ARENA_HALF + 0.5, WALL_HEIGHT * 0.5, 0), wall_side, grey)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	add_child(sun)


func _add_box(pos: Vector3, size: Vector3, color: Color, transparent: bool = false) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)

	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box_mesh.material = mat
	mesh.mesh = box_mesh
	body.add_child(mesh)

	add_child(body)
