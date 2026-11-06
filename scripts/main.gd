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

# Cyber Grind palette — neon-on-dark.
const NEON_CYAN := Color(0.0, 1.0, 1.0)
const NEON_MAGENTA := Color(1.0, 0.2, 0.6)

var players: Node3D
var spawner: MultiplayerSpawner


func _ready() -> void:
	_build_environment()
	_build_arena()
	_setup_networking()


func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()

	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.06, 0.03, 0.16)
	sky_mat.sky_horizon_color = Color(0.35, 0.06, 0.26)
	sky_mat.ground_bottom_color = Color(0.02, 0.01, 0.05)
	sky_mat.ground_horizon_color = Color(0.16, 0.03, 0.11)
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky

	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9

	e.fog_enabled = true
	e.fog_light_color = Color(0.45, 0.12, 0.35)
	e.fog_density = 0.006

	e.glow_enabled = true
	e.glow_intensity = 1.2
	e.glow_bloom = 0.04

	e.tonemap_mode = Environment.TONE_MAPPER_ACES

	env.environment = e
	add_child(env)


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
	# Transparent floor.
	_add_box(Vector3(0, -0.5, 0), Vector3(ARENA_HALF * 2, 1, ARENA_HALF * 2), Color(0.1, 0.1, 0.16, 0.35), true)

	# Neon grid overlay on the floor.
	_add_grid()

	# Two black walls (Z axis) with cyan neon trim.
	var black := Color(0.04, 0.04, 0.05)
	var wall_size := Vector3(ARENA_HALF * 2, WALL_HEIGHT, 1)
	_add_box(Vector3(0, WALL_HEIGHT * 0.5, -ARENA_HALF - 0.5), wall_size, black, false, 0.3, 0.4)
	_add_box(Vector3(0, WALL_HEIGHT * 0.5, ARENA_HALF + 0.5), wall_size, black, false, 0.3, 0.4)
	_add_emissive_line(Vector3(0, WALL_HEIGHT, -ARENA_HALF - 0.5), Vector3(ARENA_HALF * 2, 0.08, 0.04), NEON_CYAN, 3.0)
	_add_emissive_line(Vector3(0, WALL_HEIGHT, ARENA_HALF + 0.5), Vector3(ARENA_HALF * 2, 0.08, 0.04), NEON_CYAN, 3.0)

	# Two grey walls (X axis) with magenta neon trim.
	var grey := Color(0.26, 0.26, 0.3)
	var wall_side := Vector3(1, WALL_HEIGHT, ARENA_HALF * 2)
	_add_box(Vector3(-ARENA_HALF - 0.5, WALL_HEIGHT * 0.5, 0), wall_side, grey, false, 0.3, 0.4)
	_add_box(Vector3(ARENA_HALF + 0.5, WALL_HEIGHT * 0.5, 0), wall_side, grey, false, 0.3, 0.4)
	_add_emissive_line(Vector3(-ARENA_HALF - 0.5, WALL_HEIGHT, 0), Vector3(0.04, 0.08, ARENA_HALF * 2), NEON_MAGENTA, 3.0)
	_add_emissive_line(Vector3(ARENA_HALF + 0.5, WALL_HEIGHT, 0), Vector3(0.04, 0.08, ARENA_HALF * 2), NEON_MAGENTA, 3.0)

	# Key + fill lights.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, -35, 0)
	key.light_energy = 1.2
	key.light_color = Color(1.0, 0.9, 0.85)
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 130, 0)
	fill.light_energy = 0.4
	fill.light_color = Color(0.4, 0.5, 1.0)
	add_child(fill)


func _add_grid() -> void:
	var step := 4.0
	var count := int(ARENA_HALF * 2 / step)
	for i in range(-count, count + 1):
		var d := i * step
		_add_emissive_line(Vector3(0, 0.02, d), Vector3(ARENA_HALF * 2, 0.02, 0.02), NEON_CYAN, 1.5)
		_add_emissive_line(Vector3(d, 0.02, 0), Vector3(0.02, 0.02, ARENA_HALF * 2), NEON_CYAN, 1.5)


func _add_emissive_line(pos: Vector3, size: Vector3, color: Color, energy: float) -> void:
	var mesh := MeshInstance3D.new()
	mesh.position = pos
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	box_mesh.material = mat
	mesh.mesh = box_mesh
	add_child(mesh)


func _add_box(pos: Vector3, size: Vector3, color: Color, transparent: bool = false, metallic: float = 0.0, roughness: float = 0.5) -> void:
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
	mat.metallic = metallic
	mat.roughness = roughness
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box_mesh.material = mat
	mesh.mesh = box_mesh
	body.add_child(mesh)

	add_child(body)
