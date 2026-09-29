extends SceneTree
## 場面を開いて、何秒か待ってから画面を PNG に写す（見た目の確認用）。
##
##   godot --path . --script tests/capture.gd -- res://scenes/stage1.tscn 2.0 /tmp/out.png [keys...]
##
## keys は「秒:動作:秒数」を並べたもの（例 0.5:right:1.0 = 0.5 秒後に右を 1 秒押す）。

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scene := args[0]
	var secs := float(args[1])
	var out := args[2]
	var keys := Array(args.slice(3)).filter(func(k): return ":" in k)
	change_scene_to_file(scene)
	var t0 := Time.get_ticks_msec()
	for k in keys:
		var parts: PackedStringArray = k.split(":")
		_press_later(float(parts[0]), parts[1], float(parts[2]))
	while (Time.get_ticks_msec() - t0) / 1000.0 < secs:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	quit()

func _press_later(at: float, action: String, dur: float) -> void:
	await create_timer(at).timeout
	Input.action_press(action)
	await create_timer(dur).timeout
	Input.action_release(action)
