extends Node2D

signal game_won

# --- SETTINGS ---
var screen_size = Vector2(1024, 768)
var ground_y = 630.0
var gravity = 2200.0
var jump_force = -800.0
var game_speed = 350.0
var spawn_timer = 0.0
var time_to_survive = 30.0

# --- NODES ---
var player: ColorRect
var ground: ColorRect
var alien: ColorRect
var ufo: Node2D
var alien_speech: Label
var speech_bg: Panel
var laser: ColorRect
var score_label: Label
var timer_label: Label
var status_label: Label
var hint_label: Label

var player_vel_y = 0.0
var is_jumping = false
var is_dead = false
var has_won = false
var game_started = false
var intro_timer = 0.0
var time_left = 30.0
var obstacles: Array = []
var clouds: Array = []
var alien_state = "hidden"
var alien_timer = 0.0

func make_character_sprite(image_path: String, sprite_scale: float) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = load(image_path)
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	sprite.centered = true
	return sprite

func make_ufo_placeholder() -> Node2D:
	# PLACEHOLDER UFO - only appears when you lose
	var ufo_node = Node2D.new()
	
	# Body
	var body = ColorRect.new()
	body.size = Vector2(110, 32)
	body.position = Vector2(-55, -10)
	body.color = Color(0.7, 0.7, 0.75)
	ufo_node.add_child(body)
	
	# Dome
	var dome = ColorRect.new()
	dome.size = Vector2(40, 26)
	dome.position = Vector2(-20, -34)
	dome.color = Color(0.6, 0.9, 1.0)
	ufo_node.add_child(dome)
	
	# Lights
	for i in range(4):
		var light = ColorRect.new()
		light.size = Vector2(12, 9)
		light.position = Vector2(-40 + i * 26, 10)
		light.color = Color(1, 0.8, 0.0)
		ufo_node.add_child(light)
	
	# Gun underneath
	var gun = ColorRect.new()
	gun.size = Vector2(10, 16)
	gun.position = Vector2(-5, 22)
	gun.color = Color(0.3, 0.3, 0.3)
	ufo_node.add_child(gun)
	
	return ufo_node

func _ready():
	# Sky
	var bg = TextureRect.new()
	bg.size = screen_size
	# --- BACKGROUND IMAGE ---)
	bg.texture = load("res://Planet_1.png")
	bg.size = Vector2(1024, 768)
	bg.position = Vector2(0, 0)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	
	# Clouds
	for i in range(4):
		var cloud = ColorRect.new()
		cloud.size = Vector2(randf_range(60, 120), 25)
		cloud.position = Vector2(randf_range(0, 1024), randf_range(50, 200))
		cloud.color = Color(1, 1, 1, 0.8)
		add_child(cloud)
		clouds.append(cloud)
	
	# Ground - GREY LINE REMOVED, no more ground ColorRect here
	
	for i in range(20):
		var dash = ColorRect.new()
		dash.size = Vector2(30, 4)
		dash.position = Vector2(i * 70, ground_y + 90)
		dash.color = Color(0.3, 0.3, 0.3, 0.5)
		dash.name = "Dash"
		add_child(dash)
	
	# Player - ASTRONAUT
	player = ColorRect.new()
	player.size = Vector2(50, 60)
	player.position = Vector2(150, ground_y)
	player.color = Color(0, 0, 0, 0)
	add_child(player)
	var player_sprite = make_character_sprite("res://astronaut.png", 0.25)
	player_sprite.position = Vector2(25, 30)
	player.add_child(player_sprite)
	
	# ALIEN - CHASES BEHIND YOU with alien.png
	alien = ColorRect.new()
	alien.size = Vector2(60, 70)
	alien.position = Vector2(60, ground_y - 10)
	alien.color = Color(0, 0, 0, 0)
	alien.visible = true
	add_child(alien)
	var alien_sprite = make_character_sprite("res://alien.png", 0.10)
	alien_sprite.position = Vector2(30, 35)
	alien.add_child(alien_sprite)
	
	# UFO - HIDDEN, only appears when you lose
	ufo = make_ufo_placeholder()
	ufo.position = Vector2(800, -100)
	ufo.visible = false
	add_child(ufo)
	
	# Alien Speech Bubble - "AVOID THE GAS!" - CENTRED, ROUNDED, PIXEL FONT
	var pixel_font = load("res://pixel_font.ttf") as FontFile
	
	# Rounded background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.32, 0.12, 0.85) # burnt orange, see-through
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	# Thin lighter border so it still pops a bit
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(1, 0.6, 0.3, 0.9)
	
	speech_bg = Panel.new()
	speech_bg.size = Vector2(420, 70)
	# CENTRED: (1024 - 420) / 2 = 302, y in middle-ish above the ground
	speech_bg.position = Vector2(302, 400)
	speech_bg.add_theme_stylebox_override("panel", style)
	add_child(speech_bg)
	
	alien_speech = Label.new()
	alien_speech.position = Vector2(302, 420)
	alien_speech.size = Vector2(420, 40)
	alien_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alien_speech.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	alien_speech.add_theme_font_override("font", pixel_font)
	alien_speech.add_theme_font_size_override("font_size", 20)
	alien_speech.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	alien_speech.text = "AVOID THE GAS!"
	add_child(alien_speech)
	
	# Laser - fired from UFO
	laser = ColorRect.new()
	laser.size = Vector2(10, 10)
	laser.color = Color(1, 0, 0)
	laser.visible = false
	add_child(laser)
	
	# Timer - CENTRED, 0.1s like Pong
	timer_label = Label.new()
	timer_label.position = Vector2(0, 10)
	timer_label.size = Vector2(1024, 60)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 48)
	timer_label.text = "30.0"
	add_child(timer_label)
	
	var timer_text = Label.new()
	timer_text.position = Vector2(0, 65)
	timer_text.size = Vector2(1024, 30)
	timer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_text.add_theme_font_size_override("font_size", 20)
	timer_text.text = "SURVIVE 30 SECONDS!"
	add_child(timer_text)
	
	# Hint - CENTRED
	hint_label = Label.new()
	hint_label.position = Vector2(0, 415)
	hint_label.size = Vector2(1024, 30)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 24)
	hint_label.text = ""
	hint_label.visible = true
	add_child(hint_label)
	
	# Status - CENTRED
	status_label = Label.new()
	status_label.position = Vector2(0, 296)
	status_label.size = Vector2(1024, 70)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 56)
	status_label.text = ""
	add_child(status_label)
	
	game_started = false
	intro_timer = 0.0

func _physics_process(delta):
	# --- INTRO: Alien behind you says RUN! ---
	if not game_started and not is_dead and not has_won:
		intro_timer += delta
		alien.position = Vector2(60, ground_y - 10 + sin(Time.get_ticks_msec() / 300.0) * 6)
		if intro_timer > 2.2:
			game_started = true
			speech_bg.visible = false
			alien_speech.visible = false
			hint_label.text = "Press SPACE to Jump!"
		return
	
	if is_dead:
		update_ufo_death(delta)
		if Input.is_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return
	
	if has_won:
		# Alien stops chasing, UFO never appears
		if Input.is_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return
	
	# --- TIMER - 0.1 increments ---
	time_left -= delta
	timer_label.text = "%.1f" % max(time_left, 0.0)
	
	if time_left <= 0:
		win_game()
		return
	
	game_speed = 350 + (30.0 - time_left) * 12
	
	for c in clouds:
		c.position.x -= 30 * delta
		if c.position.x < -120:
			c.position.x = 1024
			c.position.y = randf_range(50, 200)
	
	for child in get_children():
		if child.name == "Dash":
			child.position.x -= game_speed * delta
			if child.position.x < -40:
				child.position.x = 1024
	
	if (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_UP) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and not is_jumping:
		player_vel_y = jump_force
		is_jumping = true
		hint_label.visible = false
	
	player_vel_y += gravity * delta
	player.position.y += player_vel_y * delta
	
	if player.position.y >= ground_y:
		player.position.y = ground_y
		player_vel_y = 0
		is_jumping = false
	
	# --- ALIEN CHASES BEHIND YOU ---
	# Always 90px behind, follows your jump, with bob + little run wobble
	var target_alien_pos = Vector2(player.position.x - 90, player.position.y - 10 + sin(Time.get_ticks_msec() / 150.0) * 4)
	alien.position = alien.position.lerp(target_alien_pos, delta * 10)
	
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_obstacle()
		spawn_timer = randf_range(0.9, 1.7)
	
	for obs in obstacles.duplicate():
		obs.position.x -= game_speed * delta
		
		if player.position.x < obs.position.x + obs.size.x \
		and player.position.x + player.size.x > obs.position.x \
		and player.position.y < obs.position.y + obs.size.y \
		and player.position.y + player.size.y > obs.position.y:
			start_death()
			return
		
		if obs.position.x < -100:
			obs.queue_free()
			obstacles.erase(obs)

func spawn_obstacle():
	var obs = _make_cloud_obstacle()
	obs.position = Vector2(1060, ground_y + 60 - obs.size.y)
	add_child(obs)
	obstacles.append(obs)
	
	# Sometimes spawn a second one close behind
	if randf() > 0.7:
		var obs2 = _make_cloud_obstacle()
		obs2.position = Vector2(1100, ground_y + 60 - obs2.size.y)
		add_child(obs2)
		obstacles.append(obs2)

func _make_cloud_obstacle() -> ColorRect:
	# Invisible box for collision, with a picture inside
	var obs = ColorRect.new()
	obs.color = Color(0, 0, 0, 0) # transparent - you only see the picture
	
	var sprite = Sprite2D.new()
	# 3-way mix: 0 = Short Cloud, 1 = Tall Cloud, 2 = Rock
	var pick = randi() % 3
	if pick == 0:
		sprite.texture = load("res://Short_Cloud.png")
	elif pick == 1:
		sprite.texture = load("res://Tall_Cloud.png")
	else:
		sprite.texture = load("res://rock.png")
	
	# Same scale for all
	sprite.scale = Vector2(0.10, 0.10)
	
	# Hitbox = EXACT size of the picture on screen
	# texture size * scale = real visual size
	obs.size = sprite.texture.get_size() * sprite.scale
	
	# Make hitbox slightly forgiving - 85% of picture, so you don't die on a wispy edge
	obs.size *= 0.85
	
	sprite.centered = true
	sprite.position = obs.size / 2
	obs.add_child(sprite)
	return obs

func start_death():
	is_dead = true
	player_vel_y = 0
	# Alien stops, UFO appears from top
	ufo.visible = true
	ufo.position = Vector2(800, -100)
	alien_state = "appearing"
	alien_timer = 0.0
	hint_label.visible = false

func update_ufo_death(delta):
	alien_timer += delta
	
	if alien_state == "appearing":
		# UFO flies down to top of screen
		ufo.position = ufo.position.lerp(Vector2(800, 120), delta * 5)
		# Alien stays behind, watching
		if alien_timer > 0.8:
			alien_state = "shooting"
			alien_timer = 0.0
			laser.visible = true
	
	elif alien_state == "shooting":
		# Laser from UFO gun to player
		var start = Vector2(ufo.position.x, ufo.position.y + 22)
		var end = Vector2(player.position.x + 25, player.position.y + 30)
		var dist = start.distance_to(end)
		laser.position = start
		laser.size = Vector2(dist, 8)
		laser.rotation = start.angle_to_point(end)
		laser.color = Color(1, randf_range(0.2, 0.5), 0.2)
		player.position.x += randf_range(-2, 2)
		if alien_timer > 0.9:
			alien_state = "done"
			laser.visible = false
			status_label.text = "ZAPPED BY UFO!"
			status_label.add_theme_color_override("font_color", Color(1, 0, 0))
			show_restart("Press R to try again")
	
	elif alien_state == "done":
		ufo.position.y = 120 + sin(Time.get_ticks_msec() / 300.0) * 10

func win_game():
	has_won = true
	for obs in obstacles:
		obs.queue_free()
	obstacles.clear()
	
	status_label.text = "YOU WON!"
	status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.4))
	timer_label.text = "0.0"
	show_restart("You survived! Press R to play again")
	emit_signal("game_won")

func show_restart(text: String):
	var restart = Label.new()
	restart.position = Vector2(0, 426)
	restart.size = Vector2(1024, 30)
	restart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart.add_theme_font_size_override("font_size", 24)
	restart.text = text
	add_child(restart)
