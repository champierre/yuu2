extends "res://tests/helper.gd"
## 縦持ちのスマホでも横向きに出ること。
## 窓が縦長になると、640x360 の絵が 90 度回って縦の窓いっぱいに出て、
## 指の座標もそれに合って届く。横長に戻すと元に戻る。

func _test() -> void:
	var game := root.get_node("Game")

	## 縦長の窓（360x720）。倍率 1 で、上下に 40 ずつ余白。
	root.size = Vector2i(360, 720)
	await process_frame
	await process_frame
	check(root.get_visible_rect().size == Vector2(640, 360), "縦長でも Window は 640x360 のまま")
	var xf := root.get_screen_transform()
	check(_near(xf * Vector2(0, 0), Vector2(0, 680)), "左上の角が、縦の窓の左下へ行く")
	check(_near(xf * Vector2(640, 0), Vector2(0, 40)), "右上の角が、縦の窓の左上へ行く")
	check(_near(xf * Vector2(640, 360), Vector2(360, 40)), "右下の角が、縦の窓の右上へ行く")
	check(_near(xf * Vector2(0, 360), Vector2(360, 680)), "左下の角が、縦の窓の右下へ行く")
	check(is_equal_approx(root.oversampling_override, 1.0), "字の解像度も倍率に合わせる")

	## 大きい縦長の窓（1170x2532、iPhone 級）。横幅で決まる倍率 3.25。
	root.size = Vector2i(1170, 2532)
	await process_frame
	xf = root.get_screen_transform()
	var k := 1170.0 / 360.0
	var top := (2532.0 - 640.0 * k) / 2.0
	check(_near(xf * Vector2(640, 0), Vector2(0, top)), "大きい縦長でも角が合う")
	check(_near(xf * Vector2(0, 360), Vector2(1170, top + 640 * k)), "大きい縦長でも反対の角が合う")
	check(_near(xf * Vector2(320, 180), Vector2(585, 1266)), "真ん中は真ん中")

	## 指の座標も回って届く。「決」（588, 300）は縦の窓では (300k, 52k + top)。
	var pad := TouchPad.new()
	root.add_child(pad)
	await process_frame
	await touch(Vector2(300 * k, 52 * k + top), true)
	check(Input.is_action_pressed("act"), "縦持ちで 決 の場所を押すと act が入る")
	await touch(Vector2(300 * k, 52 * k + top), false)
	check(not Input.is_action_pressed("act"), "離すと切れる")
	## 回っていなければ当たっていた場所（横持ちの 決 の座標そのまま）は、外れる。
	await touch(Vector2(588, 300), true)
	check(not Input.is_action_pressed("act"), "回す前の場所を押しても入らない")
	await touch(Vector2(588, 300), false)
	pad.queue_free()
	await process_frame

	## タイトルで、回った先の「決」が本当に効く。
	change_scene_to_file("res://scenes/title.tscn")
	await sleep(0.5)
	var title := current_scene
	title.add_child(TouchPad.new())
	await process_frame
	var down := Vector2(320 * k, (640 - 74) * k + top)   ## 「下」(74, 320)
	await touch(down, true)
	await touch(down, false)
	check(title._sel == 1, "縦持ちのタイトルで 下 が効く")

	## 横長に戻すと元に戻る。
	root.size = Vector2i(1280, 720)
	await process_frame
	xf = root.get_screen_transform()
	check(_near(xf * Vector2(0, 0), Vector2(0, 0)) and _near(xf * Vector2(640, 360), Vector2(1280, 720)), "横長に戻すと回らない")
	check(root.global_canvas_transform == Transform2D.IDENTITY, "横長では global_canvas_transform は素のまま")
	check(is_zero_approx(root.oversampling_override), "横長では字の解像度は自動")

	## 変換だけの計算も確かめる（正方形に近い窓は横長扱い）。
	check(game.portrait_scale(Vector2(360, 720)) == 1.0, "倍率の計算")
	check(_near(game.portrait_screen_transform(Vector2(720, 1440)) * Vector2(640, 360), Vector2(720, 80)), "変換の計算")

func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.5

func touch(p: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.position = p
	ev.pressed = pressed
	Input.parse_input_event(ev)
	await process_frame
	await process_frame
