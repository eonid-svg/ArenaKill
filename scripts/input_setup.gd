extends Node
## Configures input actions at startup so we don't have to hand-edit
## project.godot's [input] section (which is a brittle serialized format).

func _ready() -> void:
	_setup_actions()


func _setup_actions() -> void:
	_key_action("move_forward", KEY_W)
	_key_action("move_back", KEY_S)
	_key_action("move_left", KEY_A)
	_key_action("move_right", KEY_D)
	_key_action("jump", KEY_SPACE)
	_key_action("sprint", KEY_SHIFT)
	_key_action("dash", KEY_CTRL)
	_key_action("slam", KEY_C)
	_key_action("shoot", KEY_F)  # primary fire is mouse left too, added below
	_mouse_action("shoot", MOUSE_BUTTON_LEFT)
	_key_action("reload", KEY_R)


func _key_action(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		# Don't clobber if already defined; just add the key if missing.
		pass
	else:
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _mouse_action(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
