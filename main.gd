extends Node2D
# Astronaut Go Home - 1024x768 version
# Saturn (start) -> Jupiter (Pong) -> Mars (Dino) -> Earth (finish)

const STAGES := [
	{"name": "Saturn",  "tex": "res://assets/saturn.png",  "x": 512.0,  "spin": false},
	{"name": "Jupiter", "tex": "res://assets/jupiter.png", "x": 2012.0, "spin": true},
	{"name": "Mars",    "tex": "res://assets/mars.png",    "x": 3512.0, "spin": true},
	{"name": "Earth",   "tex": "res://assets/earth.png",   "x": 5012.0, "spin": true},
]

# Jupiter = Pong, Mars = Dino - Saturn and Earth have no game
const STAGE_GAMES := {
	1: "res://Pong.tscn",
	2: "res://Dino.tscn",
}

const SURFACE_Y := 560.0         # top of every planet (where the astronaut stands) - was 448 in 648 tall
const ASTEROID_COUNT := 16

const ASTRO_SCALE := 0.5
const TRAVEL_TIME := 3.0

var stage := 0
var traveling := false
var current_game = null
var game_beaten := false

var cam: Camera2D
var stars: Node2D
var planets: Array[Sprite2D] = []
var asteroids: Array = []
var time := 0.0
var astro: Node2D
var astro_sprite: Sprite2D
var idle_tween: Tween

var title_label: Label
var game_panel: PanelContainer
var game_label: Label
var next_btn: Button
var well_done: Label
var again_btn: Button
var hint_label: Label
var confetti_layer: Control

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.03, 0.03, 0.10))
	_build_world()
	_build_ui()
	_show_stage()
	_start_idle()
	hint_label.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(hint_label, "modulate:a", 1.0, 0.8)
	t.tween_interval(3.0)
	t.tween_property(hint_label, "modulate:a", 0.0, 0.8)

# ---------------------------------------------------------------- world
func _build_world() -> void:
	stars = Node2D.new()
	stars.set_script(load("res://star_field.gd"))
	add_child(stars)

	for s in STAGES:
		var p := Sprite2D.new()
		p.texture = load(s["tex"])
		p.position = Vector2(s["x"], SURFACE_Y + p.texture.get_height() * 0.5)
		add_child(p)
		planets.append(p)

	_build_asteroids()

	astro = Node2D.new()
	astro.position = _stand_pos(0)
	add_child(astro)
	astro_sprite = Sprite2D.new()
	astro_sprite.texture = load("res://assets/astronaut.png")
	astro_sprite.scale = Vector2(ASTRO_SCALE, ASTRO_SCALE)
	astro_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	astro.add_child(astro_sprite)

	cam = Camera2D.new()
	cam.position = Vector2(STAGES[0]["x"], 384.0) # center of 768
	add_child(cam)
	cam.make_current()

func _stand_pos(i: int) -> Vector2:
	var half_h: float = astro_sprite.texture.get_height() * ASTRO_SCALE * 0.5 if astro_sprite else 90.0
	return Vector2(STAGES[i]["x"], SURFACE_Y - half_h + 12.0)

func _build_asteroids() -> void:
	var tex: Texture2D = load("res://assets/asteroid.png")
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var made := 0
	while made < ASTEROID_COUNT:
		var x := rng.randf_range(-300.0, 5400.0)
		var y := rng.randf_range(70.0, 500.0)
		var blocked := false
		for s in STAGES:
			if absf(x - float(s["x"])) < 340.0:
				blocked = true
		if blocked:
			continue
		var a := Sprite2D.new()
		a.texture = tex
		var sc := rng.randf_range(0.18, 0.42)
		a.scale = Vector2(sc, sc)
		a.position = Vector2(x, y)
		add_child(a)
		asteroids.append({
			"node": a, "base": Vector2(x, y),
			"spin": rng.randf_range(-0.8, 0.8),
			"ax": rng.randf_range(20.0, 70.0), "ay": rng.randf_range(15.0, 45.0),
			"sx": rng.randf_range(0.2, 0.6), "sy": rng.randf_range(0.2, 0.6),
			"ph": rng.randf() * TAU,
		})
		made += 1

func _process(delta: float) -> void:
	time += delta
	stars.position.x = cam.position.x * 0.7 - 512.0 * 0.3
	for i in planets.size():
		if STAGES[i]["spin"]:
			planets[i].rotation += delta * (0.05 + 0.02 * i)
	for d in asteroids:
		var n: Sprite2D = d["node"]
		n.position = d["base"] + Vector2(cos(time * d["sx"] + d["ph"]) * d["ax"], sin(time * d["sy"] + d["ph"]) * d["ay"])
		n.rotation += delta * d["spin"]

# ------------------------------------------------------------------ UI - all resized to 1024x768
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	confetti_layer = Control.new()
	confetti_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	confetti_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(confetti_layer)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 18)
	title_label.size = Vector2(1024, 60)
	root.add_child(title_label)

	_build_game_panel(root)

	next_btn = Button.new()
	next_btn.text = "Next  >"
	next_btn.add_theme_font_size_override("font_size", 28)
	next_btn.position = Vector2(814, 680) # bottom-right in 1024x768
	next_btn.size = Vector2(190, 62)
	next_btn.pressed.connect(_on_next_pressed)
	root.add_child(next_btn)

	hint_label = Label.new()
	hint_label.text = "Help the astronaut get back to Earth!"
	hint_label.add_theme_font_size_override("font_size", 26)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.position = Vector2(0, 80)
	hint_label.size = Vector2(1024, 40)
	root.add_child(hint_label)

	well_done = Label.new()
	well_done.text = "Well done!"
	well_done.add_theme_font_size_override("font_size", 110)
	well_done.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	well_done.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.3))
	well_done.add_theme_constant_override("outline_size", 14)
	well_done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	well_done.position = Vector2(0, 90)
	well_done.size = Vector2(1024, 150)
	well_done.pivot_offset = Vector2(512, 75)
	well_done.visible = false
	root.add_child(well_done)

	again_btn = Button.new()
	again_btn.text = "Play again"
	again_btn.add_theme_font_size_override("font_size", 28)
	again_btn.position = Vector2(814, 680)
	again_btn.size = Vector2(190, 62)
	again_btn.visible = false
	again_btn.pressed.connect(func(): get_tree().reload_current_scene())
	root.add_child(again_btn)

func _build_game_panel(root: Control) -> void:
	game_panel = PanelContainer.new()
	game_panel.position = Vector2(262, 150) # centered: (1024-500)/2 = 262
	game_panel.size = Vector2(500, 170)
	root.add_child(game_panel)
	game_label = Label.new()
	game_label.add_theme_font_size_override("font_size", 30)
	game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_panel.add_child(game_label)

func _show_stage() -> void:
	var pname: String = STAGES[stage]["name"]
	title_label.text = pname
	var last := stage == STAGES.size() - 1
	game_panel.visible = not last
	next_btn.visible = not last
	next_btn.disabled = false
	if STAGE_GAMES.has(stage):
		var game_name = "Pong" if stage == 1 else "Dino"
		if game_beaten:
			game_label.text = "%s Game\nDone! Press Next to fly!" % pname
			next_btn.text = "Next  >"
		else:
			game_label.text = "%s Game\nPlay %s to continue!" % [pname, game_name]
			next_btn.text = "Play %s  >" % game_name
	else:
		if stage == 0:
			game_label.text = "Saturn\nPress Next to start your journey!"
		else:
			game_label.text = "%s Game\n(game goes here)" % pname
		next_btn.text = "Next  >"
	game_panel.modulate.a = 0.0
	if not last:
		create_tween().tween_property(game_panel, "modulate:a", 1.0, 0.4)

# ------------------------------------------------------------ animation
func _start_idle() -> void:
	if idle_tween:
		idle_tween.kill()
	astro_sprite.position = Vector2.ZERO
	astro_sprite.rotation = 0.0
	astro_sprite.scale = Vector2(ASTRO_SCALE, ASTRO_SCALE)
	idle_tween = create_tween().set_loops()
	idle_tween.tween_property(astro_sprite, "position:y", -8.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.tween_property(astro_sprite, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_next_pressed() -> void:
	if traveling or stage >= STAGES.size() - 1:
		return
	# If this planet has a game and we haven't beaten it, PLAY it, don't travel
	if STAGE_GAMES.has(stage) and not game_beaten:
		_launch_game(STAGE_GAMES[stage])
		return
	# Otherwise travel to next planet
	game_beaten = false
	traveling = true
	next_btn.disabled = true
	hint_label.modulate.a = 0.0
	if idle_tween:
		idle_tween.kill()
	astro_sprite.position = Vector2.ZERO

	var from := astro.position
	stage += 1
	var to := _stand_pos(stage)

	create_tween().tween_property(game_panel, "modulate:a", 0.0, 0.3)
	title_label.text = "Flying to %s..." % STAGES[stage]["name"]

	var t := create_tween().set_parallel(true)
	t.tween_property(cam, "position:x", STAGES[stage]["x"], TRAVEL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(func(p: float) -> void:
		astro.position = from.lerp(to, p) + Vector2(0.0, -sin(p * PI) * 200.0),
		0.0, 1.0, TRAVEL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(astro_sprite, "rotation", TAU * 2.0, TRAVEL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.chain().tween_callback(_arrived)

# ------------------------------------------------------------ games - now same 1024x768, no scaling needed
func _launch_game(path: String) -> void:
	game_panel.visible = false
	next_btn.visible = false
	title_label.visible = false
	hint_label.visible = false
	# Move camera back to 0,0 so the game at 0,0 lines up with the screen
	cam.position = Vector2(512, 384)
	current_game = load(path).instantiate()
	add_child(current_game)
	if current_game.has_signal("game_won"):
		current_game.game_won.connect(_on_game_won)
	if current_game.has_signal("game_lost"):
		current_game.game_lost.connect(_on_game_lost)

func _on_game_won() -> void:
	print("Beat game on ", STAGES[stage]["name"])
	if current_game:
		current_game.queue_free()
		current_game = null
	game_beaten = true
	# Put camera back where it was, show UI again
	cam.position = Vector2(STAGES[stage]["x"], 384.0)
	game_panel.visible = true
	next_btn.visible = true
	title_label.visible = true
	hint_label.visible = true
	_show_stage()

func _on_game_lost() -> void:
	# Pong/Dino will already show "You lost" - just let them retry
	# If your game frees itself on lose, this keeps the travel UI hidden until retry
	pass

func _arrived() -> void:
	astro_sprite.rotation = 0.0
	var sq := create_tween()
	sq.tween_property(astro_sprite, "scale", Vector2(ASTRO_SCALE * 1.25, ASTRO_SCALE * 0.8), 0.1)
	sq.tween_property(astro_sprite, "scale", Vector2(ASTRO_SCALE, ASTRO_SCALE), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sq.tween_callback(_start_idle)
	traveling = false
	_show_stage()
	if stage == STAGES.size() - 1:
		_celebrate()

func _celebrate() -> void:
	well_done.visible = true
	well_done.scale = Vector2.ZERO
	var t := create_tween()
	t.tween_property(well_done, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): again_btn.visible = true)
	await get_tree().create_timer(0.5).timeout
	var j := create_tween().set_loops()
	j.tween_property(astro, "position:y", astro.position.y - 40.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	j.tween_property(astro, "position:y", astro.position.y, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_confetti()

func _confetti() -> void:
	var colors := [Color.HOT_PINK, Color.GOLD, Color.CYAN, Color.LIME_GREEN, Color.ORANGE, Color.WHITE]
	for i in 140:
		var c := ColorRect.new()
		c.color = colors[randi() % colors.size()]
		c.size = Vector2(randf_range(8, 16), randf_range(8, 16))
		c.position = Vector2(randf_range(0, 1024), randf_range(-300, -20))
		c.rotation = randf() * TAU
		confetti_layer.add_child(c)
		var dur := randf_range(2.5, 5.0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(c, "position:y", 768.0, dur).set_delay(randf_range(0.0, 1.5))
		tw.tween_property(c, "rotation", c.rotation + randf_range(-8, 8), dur).set_delay(0.0)
		tw.chain().tween_callback(c.queue_free)
