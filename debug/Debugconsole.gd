extends CanvasLayer

# DebugConsole.gd
# Attach this to a CanvasLayer node (autoload recommended)
# Toggle with F2 key

const MAX_LINES := 200
const HISTORY_SIZE := 50

var _history: Array[String] = []
var _history_index := -1
var _commands := {}
var _cwd := "res://"

@onready var panel: PanelContainer = $Panel
@onready var output: RichTextLabel = $Panel/VBox/Output
@onready var input: LineEdit = $Panel/VBox/InputRow/Input

var is_open := false

# ─── Built-in lifecycle ───────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	layer = 100

	# Register built-in commands
	register_command("help",      _cmd_help,      "List all commands")
	register_command("clear",     _cmd_clear,     "Clear the console output")
	register_command("cls",       _cmd_clear,     "Alias for clear")
	register_command("quit",      _cmd_quit,      "Quit the game")
	register_command("exit",      _cmd_quit,      "Alias for quit")
	register_command("reload",    _cmd_reload,    "reload's the scene")
	register_command("restart",   _cmd_reload,    "Alias for reload")
	register_command("rs",        _cmd_reload,    "Alias for reload")
	register_command("fps",       _cmd_fps,       "Show current FPS")
	register_command("timescale", _cmd_timescale, "Set Engine.time_scale <value>")
	register_command("scene",     _cmd_scene,     "Change scene: scene <path>")
	register_command("echo",      _cmd_echo,      "Print text: echo <message>")
	register_command("pos",       _cmd_pos,       "Print player position (looks for 'Player' group)")

	# Filesystem commands
	register_command("ls",        _cmd_ls,        "List files in dir: ls [path]")
	register_command("dir",       _cmd_ls,        "Alias for ls")
	register_command("cd",        _cmd_cd,        "Change directory: cd <path>")
	register_command("..",        _cmd_cd_dd,        "Change directory: cd preveus")
	register_command("pwd",       _cmd_pwd,       "Print current directory")
	register_command("cat",       _cmd_cat,       "Print file contents: cat <file>")
	register_command("mkdir",     _cmd_mkdir,     "Create directory: mkdir <path>")
	register_command("rm",        _cmd_rm,        "Delete file: rm <path>")
	register_command("cp",        _cmd_cp,        "Copy file: cp <src> <dst>")
	register_command("mv",        _cmd_mv,        "Move/rename file: mv <src> <dst>")
	register_command("exists",    _cmd_exists,    "Check if file/dir exists: exists <path>")

	input.text_submitted.connect(_on_input_submitted)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			toggle()
			get_viewport().set_input_as_handled()
		# Arrow key history navigation
		if is_open and input.has_focus():
			if event.keycode == KEY_UP:
				_navigate_history(1)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_DOWN:
				_navigate_history(-1)
				get_viewport().set_input_as_handled()

# ─── Public API ───────────────────────────────────────────────────────────────

func register_command(name: String, cb: Callable, description := "") -> void:
	_commands[name.to_lower()] = { "cb": cb, "desc": description }

func log_line(text: String, color := "") -> void:
	var line := text
	if color != "":
		line = "[color=%s]%s[/color]" % [color, text]
	output.append_text(line + "\n")
	if output.get_line_count() > MAX_LINES:
		output.clear()
		output.append_text("[color=gray]... (log trimmed) ...[/color]\n")

func toggle() -> void:
	is_open = !is_open
	panel.visible = is_open
	if is_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		input.grab_focus()
		input.clear()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		input.release_focus()

# ─── Input handling ───────────────────────────────────────────────────────────

func _on_input_submitted(text: String) -> void:
	text = text.strip_edges()
	if text.is_empty():
		return

	log_line("> " + text, "#aaffaa")
	_add_history(text)
	input.clear()
	_history_index = -1

	_execute(text)
	input.grab_focus()

func _navigate_history(dir: int) -> void:
	if _history.is_empty():
		return
	_history_index = clamp(_history_index + dir, 0, _history.size() - 1)
	input.text = _history[_history.size() - 1 - _history_index]
	input.caret_column = input.text.length()

func _add_history(text: String) -> void:
	if _history.is_empty() or _history.back() != text:
		_history.append(text)
	if _history.size() > HISTORY_SIZE:
		_history.pop_front()

# ─── Command execution ────────────────────────────────────────────────────────

func _execute(raw: String) -> void:
	var parts := raw.split(" ", false)
	if parts.is_empty():
		return
	var cmd := parts[0].to_lower()
	var args := parts.slice(1) as Array

	if _commands.has(cmd):
		var result: String = _commands[cmd]["cb"].call(args)
		if result != "":
			log_line(result)
	else:
		log_line("Unknown command: '%s'  (type 'help' for list)" % cmd, "#ff8888")

# ─── Helper: resolve path ─────────────────────────────────────────────────────

func _resolve(path: String) -> String:
	if path.is_empty():
		return _cwd
	if path.begins_with("res://") or path.begins_with("user://"):
		return path
	if path == "..":
		var parts := _cwd.rstrip("/").rsplit("/", false, 1)
		if parts.size() > 1:
			return parts[0] + "/"
		return _cwd
	return _cwd.rstrip("/") + "/" + path

# ─── Built-in command implementations ────────────────────────────────────────

func _cmd_help(_args) -> String:
	var lines := ["[b]Available commands:[/b]"]
	for name in _commands.keys():
		var desc: String = _commands[name]["desc"]
		if desc.begins_with("Alias"):
			lines.append("  [color=#888888]%-14s[/color] %s" % [name, desc])
		else:
			lines.append("  [color=cyan]%-14s[/color] %s" % [name, desc])
	return "\n".join(lines)

func _cmd_clear(_args) -> String:
	output.clear()
	return ""

func _cmd_quit(_args) -> String:
	get_tree().quit()
	return ""

func _cmd_reload(_args) -> String:
	get_tree().reload_current_scene()
	return "Restarting..."

func _cmd_fps(_args) -> String:
	return "FPS: %d" % Engine.get_frames_per_second()

func _cmd_timescale(args) -> String:
	if args.is_empty():
		return "time_scale = %s" % Engine.time_scale
	var val := float(args[0])
	Engine.time_scale = val
	return "time_scale set to %s" % val

func _cmd_scene(args) -> String:
	if args.is_empty():
		return "[error] Usage: scene <res://path/to/scene.tscn>"
	var path: String = _resolve(args[0])
	if not ResourceLoader.exists(path):
		return "[error] Scene not found: " + path
	get_tree().change_scene_to_file(path)
	return "Loading: " + path

func _cmd_echo(args) -> String:
	return " ".join(args)

func _cmd_pos(_args) -> String:
	var players := get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		return "[warn] No node in group 'Player' found."
	var lines := []
	for p in players:
		if p is Node2D:
			lines.append("%s pos: %s" % [p.name, p.position])
		elif p is Node3D:
			lines.append("%s pos: %s" % [p.name, p.position])
	return "\n".join(lines)

# ─── Filesystem commands ──────────────────────────────────────────────────────

func _cmd_ls(args) -> String:
	var path := _resolve(args[0] if not args.is_empty() else "")
	var dir := DirAccess.open(path)
	if dir == null:
		return "[error] Cannot open: " + path
	dir.list_dir_begin()
	var entries := []
	var fname := dir.get_next()
	while fname != "":
		if fname != "." and fname != "..":
			if dir.current_is_dir():
				entries.append("[color=yellow]%s/[/color]" % fname)
			else:
				entries.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	if entries.is_empty():
		return "(empty)"
	entries.sort()
	return "\n".join(entries)

func _cmd_cd(args) -> String:
	if args.is_empty():
		_cwd = "res://"
		return _cwd
	var path := _resolve(args[0])
	var dir := DirAccess.open(path)
	if dir == null:
		return "[error] Directory not found: " + path
	_cwd = path.rstrip("/") + "/"
	print(args)
	return _cwd

func _cmd_cd_dd(args) -> String:
	return _cmd_cd([".."])

func _cmd_pwd(_args) -> String:
	return _cwd

func _cmd_cat(args) -> String:
	if args.is_empty():
		return "[error] Usage: cat <file>"
	var path := _resolve(args[0])
	if not FileAccess.file_exists(path):
		return "[error] File not found: " + path
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "[error] Cannot read: " + path
	var content := file.get_as_text()
	file.close()
	if content.length() > 2000:
		return content.substr(0, 2000) + "\n[color=gray]... (truncated)[/color]"
	return content

func _cmd_mkdir(args) -> String:
	if args.is_empty():
		return "[error] Usage: mkdir <path>"
	var path := _resolve(args[0])
	var err := DirAccess.make_dir_recursive_absolute(path)
	if err != OK:
		return "[error] Failed to create dir (code %d)" % err
	return "Created: " + path

func _cmd_rm(args) -> String:
	if args.is_empty():
		return "[error] Usage: rm <path>"
	var path := _resolve(args[0])
	if DirAccess.dir_exists_absolute(path):
		var err := DirAccess.remove_absolute(path)
		if err != OK:
			return "[error] Failed to remove dir (code %d) - must be empty" % err
		return "Removed dir: " + path
	elif FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		if err != OK:
			return "[error] Failed to remove file (code %d)" % err
		return "Removed: " + path
	return "[error] Not found: " + path

func _cmd_cp(args) -> String:
	if args.size() < 2:
		return "[error] Usage: cp <src> <dst>"
	var src := _resolve(args[0])
	var dst := _resolve(args[1])
	if not FileAccess.file_exists(src):
		return "[error] Source not found: " + src
	var err := DirAccess.copy_absolute(src, dst)
	if err != OK:
		return "[error] Copy failed (code %d)" % err
	return "Copied: %s -> %s" % [src, dst]

func _cmd_mv(args) -> String:
	if args.size() < 2:
		return "[error] Usage: mv <src> <dst>"
	var src := _resolve(args[0])
	var dst := _resolve(args[1])
	if not FileAccess.file_exists(src):
		return "[error] Source not found: " + src
	var err := DirAccess.rename_absolute(src, dst)
	if err != OK:
		return "[error] Move failed (code %d)" % err
	return "Moved: %s -> %s" % [src, dst]

func _cmd_exists(args) -> String:
	if args.is_empty():
		return "[error] Usage: exists <path>"
	var path := _resolve(args[0])
	if FileAccess.file_exists(path):
		return "[color=green]EXISTS[/color] (file): " + path
	elif DirAccess.dir_exists_absolute(path):
		return "[color=green]EXISTS[/color] (dir): " + path
	else:
		return "[color=red]NOT FOUND[/color]: " + path
