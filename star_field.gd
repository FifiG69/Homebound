extends Node2D
# Draws a bunch of random stars. Main moves this node slower than the camera
# so the stars look far away (parallax).

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in 450:
		var p := Vector2(rng.randf_range(-700.0, 2800.0), rng.randf_range(0.0, 648.0))
		var r := rng.randf_range(0.8, 2.6)
		var c := Color(1, 1, rng.randf_range(0.7, 1.0), rng.randf_range(0.4, 1.0))
		draw_circle(p, r, c)
