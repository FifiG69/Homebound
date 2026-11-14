extends Node2D

signal game_won

# --- SETTINGS ---
var screen_size = Vector2(1024, 768)
var paddle_size = Vector2(20, 120)
var ball_size = Vector2(20, 20)
var player_speed = 600.0
var ai_speed = 430.0
var ball_speed = 450.0
var ball_base_speed = 450.0
var speed_increase_per_second = 10.0
var time_to_survive = 30.0

# --- NODES ---
var player: ColorRect
var enemy: ColorRect
var ball: ColorRect
var ball_dir: Vector2 = Vector2(1, 0.3).normalized()
var timer_label: Label
var status_label: Label
var time_left = 0.0
var game_over = false
var ball_stopped = false

func make_character_sprite(image_path: String, sprite_scale: float) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = load(image_path)
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	sprite.centered = true
	return sprite

func _ready():
	# Background
	var bg = TextureRect.new()
	bg.size = screen_size
	# --- BACKGROUND IMAGE ---)
	bg.texture = load("res://Planet_2.png")
	bg.size = Vector2(1024, 768)
	bg.position = Vector2(0, 0)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	
	# Center line
	for y in range(0, 768, 40):
		var dash = ColorRect.new()
		dash.size = Vector2(6, 20)
		dash.position = Vector2(509, y)
		dash.color = Color(1, 1, 1, 0.3)
		add_child(dash)
	
	# Player Paddle - ASTRONAUT (YOU)
	player = ColorRect.new()
	player.size = paddle_size
	player.color = Color(0.2, 0.8, 1)
	player.position = Vector2(50, 384 - paddle_size.y / 2)
	add_child(player)
	var astronaut = make_character_sprite("res://astronaut.png", 0.25)
	astronaut.position = Vector2(10, -50)
	player.add_child(astronaut)
	
	# Enemy AI Paddle - ALIEN
	enemy = ColorRect.new()
	enemy.size = paddle_size
	enemy.color = Color(0.4, 1, 0.4)
	enemy.position = Vector2(1024 - 50 - paddle_size.x, 384 - paddle_size.y / 2)
	add_child(enemy)
	var alien = make_character_sprite("res://alien.png", 0.08)
	alien.position = Vector2(10, -50)
	enemy.add_child(alien)
	
	# Ball
	ball = ColorRect.new()
	ball.size = ball_size
	ball.color = Color.WHITE
	ball.position = Vector2(512, 384)
	add_child(ball)
	
	# Timer - CENTRED
	timer_label = Label.new()
	timer_label.position = Vector2(0, 10)
	timer_label.size = Vector2(1024, 60)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 48)
	timer_label.text = "30.0"
	add_child(timer_label)
	
	var survive_text = Label.new()
	survive_text.position = Vector2(0, 65)
	survive_text.size = Vector2(1024, 30)
	survive_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	survive_text.add_theme_font_size_override("font_size", 20)
	survive_text.text = "SURVIVE FOR 30 SECONDS!"
	add_child(survive_text)
	
	# Win/Lose message - CENTRED
	status_label = Label.new()
	status_label.position = Vector2(0, 340)
	status_label.size = Vector2(1024, 80)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 64)
	status_label.text = ""
	add_child(status_label)
	
	reset_ball()

func _physics_process(delta):
	if game_over:
		if Input.is_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return
	
	# --- TIMER ---
	time_left -= delta
	timer_label.text = "%.1f" % max(time_left, 0.0)
	
	if time_left <= 0:
		win_game()
		return
	
	# --- BALL GETS FASTER ---
	var elapsed = time_to_survive - time_left
	var time_bonus = elapsed * speed_increase_per_second
	ball_speed = max(ball_speed, ball_base_speed + time_bonus)
	
	# --- PLAYER MOVEMENT ---
	var input = 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input = -1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input = 1
	
	player.position.y += input * player_speed * delta
	player.position.y = clamp(player.position.y, 0, screen_size.y - paddle_size.y)
	
	# --- AI MOVEMENT ---
	if ball_dir.x > 0:
		var target_y = ball.position.y + ball_size.y / 2 - paddle_size.y / 2
		var diff = target_y - enemy.position.y
		if abs(diff) > 8:
			enemy.position.y += sign(diff) * ai_speed * delta
	else:
		var diff = 384 - paddle_size.y / 2 - enemy.position.y
		enemy.position.y += sign(diff) * ai_speed * 0.4 * delta
	
	enemy.position.y = clamp(enemy.position.y, 0, screen_size.y - paddle_size.y)
	
	# --- BALL MOVEMENT ---
	if ball_stopped:
		return
	
	ball.position += ball_dir * ball_speed * delta
	
	if ball.position.y <= 0:
		ball.position.y = 0
		ball_dir.y = abs(ball_dir.y)
	if ball.position.y >= screen_size.y - ball_size.y:
		ball.position.y = screen_size.y - ball_size.y
		ball_dir.y = -abs(ball_dir.y)
	
	# Bounce player paddle
	if ball.position.x <= player.position.x + paddle_size.x \
	and ball.position.x >= player.position.x \
	and ball.position.y + ball_size.y >= player.position.y \
	and ball.position.y <= player.position.y + paddle_size.y:
		ball.position.x = player.position.x + paddle_size.x + 1
		ball_dir.x = abs(ball_dir.x)
		add_angle(player)
		ball_speed += 15
	
	# Bounce enemy paddle
	if ball.position.x + ball_size.x >= enemy.position.x \
	and ball.position.x + ball_size.x <= enemy.position.x + paddle_size.x \
	and ball.position.y + ball_size.y >= enemy.position.y \
	and ball.position.y <= enemy.position.y + paddle_size.y:
		ball.position.x = enemy.position.x - ball_size.x - 1
		ball_dir.x = -abs(ball_dir.x)
		add_angle(enemy)
		ball_speed += 15
	
	if ball.position.x < -20:
		lose_game()
	
	if ball.position.x > screen_size.x + 20:
		reset_ball()

func add_angle(paddle: ColorRect):
	var paddle_center = paddle.position.y + paddle_size.y / 2
	var ball_center = ball.position.y + ball_size.y / 2
	var offset = (ball_center - paddle_center) / (paddle_size.y / 2)
	ball_dir.y = clamp(offset * 0.8, -0.9, 0.9)
	ball_dir = ball_dir.normalized()

func reset_ball():
	ball.position = Vector2(512 - ball_size.x / 2, 384 - ball_size.y / 2)
	var elapsed = time_to_survive - time_left
	ball_speed = ball_base_speed + elapsed * speed_increase_per_second
	ball_dir = Vector2([-1, 1].pick_random(), randf_range(-0.4, 0.4)).normalized()
	ball_stopped = true
	await get_tree().create_timer(0.7).timeout
	if not game_over:
		ball_stopped = false

func win_game():
	game_over = true
	ball.visible = false
	status_label.text = "YOU WON!"
	status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.4))
	emit_signal("game_won")
	show_restart()

func lose_game():
	game_over = true
	ball.visible = false
	status_label.text = "YOU LOST!"
	status_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	show_restart()

func show_restart():
	var restart = Label.new()
	restart.position = Vector2(0, 420)
	restart.size = Vector2(1024, 30)
	restart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart.add_theme_font_size_override("font_size", 24)
	restart.text = "Press R to play again"
	add_child(restart)
