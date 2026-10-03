extends "res://tests/helper.gd"
## 縦持ちのスマホでは、遊びの画面が上に、操作のボタンが下に並ぶこと。
## 窓が縦長になると、640x360 の絵が窓の上に横幅いっぱいで出て、
## ボタンはその下の帯（y が 360 より先）に移り、指の座標もそれに合って届く。
## 横長に戻すと、ボタンは遊びの画面に重なる元の場所に戻る。

func _test() -> void:
	var game := root.get_node("Game")

	## パソコン（指で遊ばない機械）は、窓が縦長でも何も変えない。
	root.size = Vector2i(400, 800)
	await process_frame
	await process_frame
	check(not game.stacked, "パソコンでは縦長の窓でも並べ替えない")
	check(root.global_canvas_transform == Transform2D.IDENTITY, "パソコンでは global_canvas_transform は素のまま")

	## ここからはスマホのふりをする。
	TouchPad.pretend = true

	## 縦長の窓（360x720）。倍率は 360/640。
	root.size = Vector2i(360, 720)
	await process_frame
	await process_frame
	check(game.stacked, "スマホの縦持ちでは、画面とボタンを上下に並べる")
	check(root.get_visible_rect().size == Vector2(640, 360), "縦長でも Window は 640x360 のまま")
	var xf := root.get_screen_transform()
	check(_near(xf * Vector2(0, 0), Vector2(0, 0)), "絵の左上が、窓の左上に来る")
	check(_near(xf * Vector2(640, 360), Vector2(360, 202.5)), "絵は横幅いっぱいで、比はそのまま")
	check(is_equal_approx(root.oversampling_override, 360.0 / 640.0), "字の解像度も倍率に合わせる")
	check(is_equal_approx(game.pad_height, 920.0), "絵の下の残りが、ぜんぶボタンの帯になる")
	check(game._pad_back.visible, "帯を塗っている（地図の続きが下に見えない）")

	## 大きい縦長の窓（1170x2532、iPhone 級）。
	root.size = Vector2i(1170, 2532)
	await process_frame
	xf = root.get_screen_transform()
	var k := 1170.0 / 640.0
	check(_near(xf * Vector2(640, 360), Vector2(1170, 360 * k)), "大きい縦長でも角が合う")

	## ボタンは絵の下にあり、そこを押すと効く。
	var pad := TouchPad.new()
	root.add_child(pad)
	await process_frame
	var act: Vector2 = pad.button_pos("act")
	check(act.y > 360, "決 は遊びの画面より下にある")
	await touch(xf * act, true)
	check(Input.is_action_pressed("act"), "縦持ちで 決 の場所を押すと act が入る")
	await touch(xf * act, false)
	check(not Input.is_action_pressed("act"), "離すと切れる")
	## 横持ちのときの場所（遊びの画面の中）を押しても、もう効かない。
	await touch(xf * Vector2(588, 300), true)
	check(not Input.is_action_pressed("act"), "遊びの画面の中を押しても入らない")
	await touch(xf * Vector2(588, 300), false)
	for b in TouchPad.BUTTONS:
		var a: String = b["action"]
		if a == "pause":
			continue
		await touch(xf * pad.button_pos(a), true)
		check(Input.is_action_pressed(a), "縦持ちで %s が効く" % b["text"])
		await touch(xf * pad.button_pos(a), false)

	## いちばん帯が低くなる窓（ほぼ正方形）でも、ボタンは帯の中に収まり、重ならない。
	root.size = Vector2i(400, 401)
	await process_frame
	check(game.stacked and game.pad_height >= 280.0, "ほぼ正方形でも帯は 280 以上ある")
	var inside := true
	var apart := true
	for b in TouchPad.BUTTONS:
		var p: Vector2 = pad.button_pos(b["action"])
		var r: float = pad.button_r(b["action"]) + TouchPad.REACH
		if p.y - r < 360 or p.y + r > 360 + game.pad_height or p.x - r < 0 or p.x + r > 640:
			inside = false
		for c in TouchPad.BUTTONS:
			if c["action"] == b["action"]:
				continue
			var r2: float = pad.button_r(c["action"]) + TouchPad.REACH
			if p.distance_to(pad.button_pos(c["action"])) < r + r2:
				apart = false
	check(inside, "どのボタンも、押せる範囲ごと帯の中に収まる")
	check(apart, "押せる範囲が、隣のボタンと重ならない")
	pad.queue_free()
	await process_frame

	## タイトルで、下の帯の「下」が本当に効く。
	root.size = Vector2i(1170, 2532)
	await process_frame
	xf = root.get_screen_transform()
	change_scene_to_file("res://scenes/title.tscn")
	await sleep(0.5)
	var title := current_scene
	pad = null
	for c in title.get_children():
		if c is TouchPad:
			pad = c
	check(pad != null, "スマホではタイトルにボタンが出る")
	var down: Vector2 = xf * pad.button_pos("down")
	await touch(down, true)
	await touch(down, false)
	check(title._sel == 1, "縦持ちのタイトルで 下 が効く")

	## 横長に戻すと、ボタンは遊びの画面に重なる元の場所に戻る。
	root.size = Vector2i(1280, 720)
	await process_frame
	xf = root.get_screen_transform()
	check(not game.stacked and is_zero_approx(game.pad_height), "横長に戻すと並べ替えをやめる")
	check(_near(xf * Vector2(0, 0), Vector2(0, 0)) and _near(xf * Vector2(640, 360), Vector2(1280, 720)), "横長では絵が窓いっぱいに出る")
	check(root.global_canvas_transform == Transform2D.IDENTITY, "横長では global_canvas_transform は素のまま")
	check(is_zero_approx(root.oversampling_override), "横長では字の解像度は自動")
	check(not game._pad_back.visible, "横長では帯を塗らない")
	check(pad.button_pos("act") == Vector2(588, 300), "横長では 決 が遊びの画面の右下に戻る")
	await touch(xf * Vector2(74, 236), true)
	await touch(xf * Vector2(74, 236), false)
	check(title._sel == 0, "横持ちのタイトルで 上 が効く")

	## 変換だけの計算も確かめる（正方形は横長扱い）。
	check(not game.is_portrait(Vector2(720, 720)) and game.is_portrait(Vector2(720, 721)), "縦長かどうかの計算")
	check(game.stacked_scale(Vector2(320, 720)) == 0.5, "倍率の計算")
	check(_near(game.stacked_screen_transform(Vector2(320, 720)) * Vector2(640, 360), Vector2(320, 180)), "変換の計算")
	TouchPad.pretend = false

func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.5

func touch(p: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.position = p
	ev.pressed = pressed
	Input.parse_input_event(ev)
	await process_frame
	await process_frame
