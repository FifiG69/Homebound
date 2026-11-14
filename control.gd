extends Control
## Main menu for Godot 4.x (space theme, pixel text)
## Attach this to the root Control node of a new scene, then tweak
## everything from the Inspector (no code changes needed).

@export_group("Title")
@export var game_title: String = "Homebound"
## ON = built-in pixel font (no font file needed). OFF = use a normal font below.
@export var pixel_text: bool = true
## Size of each "pixel" in the title (pixel text only). 6 is a good start.
@export_range(2, 16) var title_pixel_size: int = 6
## Extra empty columns between letters (pixel text only).
@export_range(1, 4) var pixel_spacing: int = 1
@export var title_color: Color = Color("e8fbff")
@export var title_outline_color: Color = Color("2b1b6b")
## Only used when Pixel Text is OFF. Drag a .ttf / .otf here (try Press Start 2P or Orbitron).
@export var title_font: Font
@export var title_size: int = 64
@export var title_outline_size: int = 10
@export var letter_spacing: int = 10
@export var title_glow_color: Color = Color(0.2, 0.85, 1.0, 0.55)

@export_group("Background")
## Drag ANY image here (png, jpg, webp...).
@export var background_image: Texture2D
## Used if no image is set.
@export var background_fallback_color: Color = Color(0.03, 0.03, 0.1)
## 0 = no darkening, 1 = fully black. Helps the text stay readable.
@export_range(0.0, 1.0) var background_dim: float = 0.3

@export_group("Starfield")
@export var show_starfield: bool = true
@export_range(0, 500) var star_count: int = 160
@export var star_color: Color = Color("dff6ff")
## How fast the stars drift sideways (pixels per second for the closest stars).
@export var star_drift_speed: float = 14.0
@export var twinkle_speed: float = 2.0
@export var show_shooting_stars: bool = true

@export_group("Asteroids")
@export var show_asteroids: bool = true
## Drag your asteroid image here. If left empty, it tries to load res://asteroid.png
@export var asteroid_texture: Texture2D
@export_range(0, 30) var asteroid_count: int = 7
## Smallest and largest asteroid width in pixels (small = far away, large = close).
@export var asteroid_min_width: float = 50.0
@export var asteroid_max_width: float = 150.0
## Drift speed in pixels per second (far asteroids move slower).
@export var asteroid_min_speed: float = 10.0
@export var asteroid_max_speed: float = 35.0
## Maximum spin in degrees per second.
@export var asteroid_max_spin: float = 20.0

@export_group("Play Button")
@export var play_text: String = "PLAY"
## Size of each "pixel" in the button text (pixel text only).
@export_range(2, 12) var button_pixel_size: int = 5
@export var button_font: Font
@export var button_font_size: int = 36
@export var button_color: Color = Color("5b3df5")
@export var button_hover_color: Color = Color("22d3ee")
@export var button_text_color: Color = Color.WHITE
## The scene to load when Play is pressed.
@export var game_scene: PackedScene

var _title_label: Control
var _play_button: Button
var _button_pixel_label: PixelLabel

# Starfield data (x/y are 0..1 across the screen, depth gives a parallax effect)
var _star_layer: Control
var _star_x := PackedFloat32Array()
var _star_y := PackedFloat32Array()
var _star_depth := PackedFloat32Array()
var _star_phase := PackedFloat32Array()
var _time := 0.0

# Asteroids
var _asteroid_layer: Control
var _asteroids: Array = []
var _asteroid_vel: Array[Vector2] = []
var _asteroid_spin: Array[float] = []

# Shooting star
var _shoot_cooldown := 3.0
var _shoot_life := 0.0
var _shoot_pos := Vector2.ZERO
var _shoot_vel := Vector2.ZERO
const SHOOT_DURATION := 0.9

## Draws text using a built-in 5x7 pixel font, so no font file is needed.
class PixelLabel extends Control:
	const GLYPHS := {
		"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
		"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
		"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
		"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
		"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
		"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
		"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
		"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
		"I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
		"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
		"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
		"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
		"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
		"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
		"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
		"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
		"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
		"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
		"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
		"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
		"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
		"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
		"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
		"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
		"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
		"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
		"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
		"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
		"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
		"3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
		"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
		"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
		"6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
		"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
		"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
		"9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
		" ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
		"!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
		"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
		".": [".....", ".....", ".....", ".....", ".....", ".....", "..#.."],
		",": [".....", ".....", ".....", ".....", ".....", "..#..", ".#..."],
		":": [".....", "..#..", ".....", ".....", "..#..", ".....", "....."],
		"-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
		"'": ["..#..", "..#..", ".#...", ".....", ".....", ".....", "....."],
	}

	var text := ""
	var color := Color.WHITE
	var outline_color := Color.BLACK
	var pixel := 6
	var spacing := 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _text_width() -> int:
		var n := text.length()
		if n == 0:
			return 0
		return (n * (5 + spacing) - spacing) * pixel

	func refresh() -> void:
		var pad := pixel * 2
		custom_minimum_size = Vector2(_text_width() + pad * 2 + pixel, 7 * pixel + pad * 2 + pixel)
		queue_redraw()

	func set_color(c: Color) -> void:
		color = c
		queue_redraw()

	func _draw() -> void:
		var origin := Vector2(floor((size.x - _text_width()) / 2.0), floor((size.y - 7 * pixel) / 2.0))
		# Drop shadow, then outline, then the text itself
		_draw_text(origin + Vector2(pixel, pixel), outline_color)
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx != 0 or dy != 0:
					_draw_text(origin + Vector2(dx, dy) * pixel, outline_color)
		_draw_text(origin, color)

	func _draw_text(origin: Vector2, c: Color) -> void:
		var x := 0
		for ch in text.to_upper():
			var g: Array = GLYPHS.get(ch, GLYPHS["?"])
			for row in 7:
				var line: String = g[row]
				for col in 5:
					if line[col] == "#":
						draw_rect(Rect2(origin + Vector2((x + col) * pixel, row * pixel), Vector2(pixel, pixel)), c)
			x += 5 + spacing

func _ready() -> void:
	# Fill the whole screen (this also resets the offsets, which keeps everything centred)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_starfield()
	_build_asteroids()
	_build_menu()
	_build_credits()
	_animate_title()
	_play_button.grab_focus()

func _process(delta: float) -> void:
	_update_asteroids(delta)
	if not show_starfield or _star_layer == null:
		return
	_time += delta
	var w := _star_layer.size.x
	if w <= 0.0:
		return

	# Drift stars sideways; closer (higher depth) stars move faster
	for i in _star_x.size():
		_star_x[i] -= (star_drift_speed * _star_depth[i] * delta) / w
		if _star_x[i] < 0.0:
			_star_x[i] += 1.0

	_update_shooting_star(delta)
	_star_layer.queue_redraw()

# ---------------------------------------------------------------- background

func _build_background() -> void:
	if background_image:
		var bg := TextureRect.new()
		bg.texture = background_image
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(bg)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		var solid := ColorRect.new()
		solid.color = background_fallback_color
		add_child(solid)
		solid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, background_dim)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# ----------------------------------------------------------------- starfield

func _build_starfield() -> void:
	if not show_starfield:
		return

	for i in star_count:
		_star_x.append(randf())
		_star_y.append(randf())
		_star_depth.append(randf_range(0.2, 1.0))
		_star_phase.append(randf() * TAU)

	_star_layer = Control.new()
	_star_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_star_layer)
	_star_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_star_layer.draw.connect(_draw_stars)

func _draw_stars() -> void:
	var s := _star_layer.size
	for i in _star_x.size():
		var depth := _star_depth[i]
		var twinkle := 0.55 + 0.45 * sin(_time * twinkle_speed * (0.6 + depth) + _star_phase[i])
		var c := star_color
		c.a = twinkle * (0.35 + 0.65 * depth)
		var radius := 0.8 + depth * 1.6
		var p := Vector2(_star_x[i] * s.x, _star_y[i] * s.y)
		_star_layer.draw_circle(p, radius, c)
		if depth > 0.8:
			# Soft glow on the brightest stars
			_star_layer.draw_circle(p, radius * 3.0, Color(c.r, c.g, c.b, c.a * 0.15))

	if _shoot_life > 0.0:
		var t := _shoot_life / SHOOT_DURATION
		var tail := _shoot_pos - _shoot_vel.normalized() * 140.0
		_star_layer.draw_line(tail, _shoot_pos, Color(star_color.r, star_color.g, star_color.b, 0.15 * t), 5.0)
		_star_layer.draw_line(tail, _shoot_pos, Color(1, 1, 1, 0.9 * t), 2.0)

func _update_shooting_star(delta: float) -> void:
	if not show_shooting_stars:
		return
	if _shoot_life > 0.0:
		_shoot_life -= delta
		_shoot_pos += _shoot_vel * delta
		return

	_shoot_cooldown -= delta
	if _shoot_cooldown <= 0.0:
		var s := _star_layer.size
		_shoot_pos = Vector2(randf_range(0.0, s.x * 0.7), randf_range(0.0, s.y * 0.4))
		_shoot_vel = Vector2(1.0, randf_range(0.3, 0.6)).normalized() * 1000.0
		_shoot_life = SHOOT_DURATION
		_shoot_cooldown = randf_range(4.0, 9.0)

# ----------------------------------------------------------------- asteroids

func _build_asteroids() -> void:
	if not show_asteroids or asteroid_count <= 0:
		return
	if asteroid_texture == null and ResourceLoader.exists("res://asteroid.png"):
		asteroid_texture = load("res://asteroid.png")
	if asteroid_texture == null:
		push_warning("No asteroid image set. Drag one into 'Asteroid Texture' in the Inspector.")
		return

	_asteroid_layer = Control.new()
	_asteroid_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_asteroid_layer)
	_asteroid_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var screen := get_viewport_rect().size
	var aspect := float(asteroid_texture.get_height()) / float(asteroid_texture.get_width())

	for i in asteroid_count:
		var depth := randf()  # 0 = far away, 1 = close
		var w := lerpf(asteroid_min_width, asteroid_max_width, depth)

		var rock := TextureRect.new()
		rock.texture = asteroid_texture
		rock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rock.stretch_mode = TextureRect.STRETCH_SCALE
		rock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rock.size = Vector2(w, w * aspect)
		rock.pivot_offset = rock.size / 2.0
		rock.rotation = randf() * TAU
		# Far asteroids are darker, which makes the scene feel deeper
		var shade := lerpf(0.45, 1.0, depth)
		rock.modulate = Color(shade, shade, shade)
		rock.position = Vector2(randf() * screen.x, randf() * screen.y)
		_asteroid_layer.add_child(rock)

		var speed := lerpf(asteroid_min_speed, asteroid_max_speed, depth)
		_asteroids.append(rock)
		_asteroid_vel.append(Vector2(-1.0, randf_range(-0.2, 0.2)).normalized() * speed)
		_asteroid_spin.append(deg_to_rad(randf_range(-asteroid_max_spin, asteroid_max_spin)))

func _update_asteroids(delta: float) -> void:
	if _asteroids.is_empty():
		return
	var screen := get_viewport_rect().size
	for i in _asteroids.size():
		var rock: TextureRect = _asteroids[i]
		rock.position += _asteroid_vel[i] * delta
		rock.rotation += _asteroid_spin[i] * delta

		# When one drifts off the left, bring it back in from the right
		if rock.position.x < -rock.size.x * 1.5:
			rock.position.x = screen.x + rock.size.x * 0.5
			rock.position.y = randf() * screen.y
		elif rock.position.y < -rock.size.y * 1.5:
			rock.position.y = screen.y + rock.size.y * 0.5
		elif rock.position.y > screen.y + rock.size.y * 1.5:
			rock.position.y = -rock.size.y * 0.5

# ---------------------------------------------------------------------- menu

func _make_pixel_label(txt: String, col: Color, outline: Color, px: int) -> PixelLabel:
	var pl := PixelLabel.new()
	pl.text = txt
	pl.color = col
	pl.outline_color = outline
	pl.pixel = px
	pl.spacing = pixel_spacing
	pl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pl.refresh()
	return pl

func _build_menu() -> void:
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 80)
	center.add_child(box)

	# --- Title ---
	var main_font: Font = null
	if pixel_text:
		_title_label = _make_pixel_label(game_title, title_color, title_outline_color, title_pixel_size)
	else:
		main_font = _spaced_font(title_font if title_font else _fallback_font())
		var lbl := Label.new()
		lbl.text = game_title
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", main_font)
		lbl.add_theme_font_size_override("font_size", title_size)
		lbl.add_theme_color_override("font_color", title_color)
		lbl.add_theme_color_override("font_outline_color", title_outline_color)
		lbl.add_theme_constant_override("outline_size", title_outline_size)
		# Neon glow
		lbl.add_theme_color_override("font_shadow_color", title_glow_color)
		lbl.add_theme_constant_override("shadow_offset_x", 0)
		lbl.add_theme_constant_override("shadow_offset_y", 0)
		lbl.add_theme_constant_override("shadow_outline_size", 20)
		_title_label = lbl
	box.add_child(_title_label)

	# --- Play button ---
	_play_button = Button.new()
	_play_button.custom_minimum_size = Vector2(320, 90)
	_play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play_button.add_theme_stylebox_override("normal", _make_style(button_color))
	_play_button.add_theme_stylebox_override("hover", _make_style(button_hover_color))
	_play_button.add_theme_stylebox_override("pressed", _make_style(button_color.darkened(0.2)))
	_play_button.add_theme_stylebox_override("focus", _make_style(button_color))

	if pixel_text:
		_play_button.text = ""
		_button_pixel_label = _make_pixel_label(play_text, button_text_color, button_color.darkened(0.6), button_pixel_size)
		_play_button.add_child(_button_pixel_label)
		_button_pixel_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		var btn_font := _spaced_font(button_font) if button_font else main_font
		_play_button.text = play_text
		_play_button.add_theme_font_override("font", btn_font)
		_play_button.add_theme_font_size_override("font_size", button_font_size)
		_play_button.add_theme_color_override("font_color", button_text_color)
		_play_button.add_theme_color_override("font_hover_color", Color("05071a"))
		_play_button.add_theme_color_override("font_pressed_color", button_text_color)
		_play_button.add_theme_color_override("font_focus_color", button_text_color)

	_play_button.pressed.connect(_on_play_pressed)
	_play_button.mouse_entered.connect(_on_button_hover.bind(true))
	_play_button.mouse_exited.connect(_on_button_hover.bind(false))
	box.add_child(_play_button)

func _make_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	if pixel_text:
		# Chunky square corners to match the pixel look
		sb.set_corner_radius_all(0)
		sb.set_border_width_all(6)
	else:
		sb.set_corner_radius_all(45)
		sb.set_border_width_all(3)
	sb.border_color = color.lightened(0.4)
	# Glow instead of a drop shadow
	sb.shadow_color = Color(color.r, color.g, color.b, 0.55)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2.ZERO
	return sb

## Wraps a font so we can widen the gaps between letters.
func _spaced_font(base: Font) -> Font:
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = letter_spacing
	return fv

## Used when Pixel Text is off and you haven't assigned a custom font.
func _fallback_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Orbitron", "Audiowide", "Eurostile", "Bank Gothic", "Agency FB", "Impact", "Sans-Serif"])
	f.font_weight = 700
	return f

func _animate_title() -> void:
	var tween := create_tween().set_loops()
	if pixel_text:
		# Scaling would blur the pixel edges, so pulse the brightness instead
		tween.tween_property(_title_label, "modulate", Color(0.75, 0.9, 1.0), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(_title_label, "modulate", Color.WHITE, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return

	# Wait one frame so the label has its final size, then pulse gently
	await get_tree().process_frame
	_title_label.pivot_offset = _title_label.size / 2.0
	tween.tween_property(_title_label, "scale", Vector2(1.04, 1.04), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_title_label, "scale", Vector2.ONE, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_button_hover(hovering: bool) -> void:
	if pixel_text:
		_button_pixel_label.set_color(Color("05071a") if hovering else button_text_color)
		return
	_play_button.pivot_offset = _play_button.size / 2.0
	var tween := create_tween()
	tween.tween_property(_play_button, "scale", Vector2(1.08, 1.08) if hovering else Vector2.ONE, 0.12)

func _on_play_pressed() -> void:
	if game_scene:
		get_tree().change_scene_to_packed(game_scene)
	else:
		print("Play pressed! Assign a scene to 'Game Scene' in the Inspector.")

func _build_credits() -> void:
	# Bottom-left credits, super small, NO outline
	if pixel_text:
		var credits := _make_pixel_label("By Fifi, Tiara, Charlotte, Tsimur, Marc, Ajwa", Color(1, 1, 1, 0.75), Color.TRANSPARENT, 2)
		credits.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(credits)
		credits.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		credits.offset_left = 12
		credits.offset_bottom = -12
		credits.offset_top = -30
	else:
		var credits := Label.new()
		credits.text = "By Fifi, Tiara, Charlotte, Tsimur, Marc, Ajwa"
		credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		credits.add_theme_font_size_override("font_size", 12)
		credits.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		credits.add_theme_constant_override("outline_size", 0)
		credits.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(credits)
		credits.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		credits.offset_left = 12
		credits.offset_bottom = -12
