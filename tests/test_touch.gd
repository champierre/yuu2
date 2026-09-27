extends "res://tests/helper.gd"
## スマホの画面のボタン（TouchPad）。
## 指の座標は、画面の座標で届く（Window が 640x360 の座標へ直してから _input に渡す）。
## ヘッドレスでも窓は 640x360 ではないので、ここを間違えると落ちるテストになる。

var pad: TouchPad

func _test() -> void:
	pad = TouchPad.new()
	root.add_child(pad)
	await process_frame

	## ボタンごとに、押すと効き、離すと切れること。
	for b in TouchPad.BUTTONS:
		var a: String = b["action"]
		await touch(b["pos"], true)
		if a == "pause":
			## 止 は押した瞬間だけ。自分で離す。
			await process_frame
			await process_frame
			check(not Input.is_action_pressed(a), "%s は押した次のコマで離れる" % b["text"])
			await touch(b["pos"], false)
			continue
		check(Input.is_action_pressed(a), "%s を押すと %s が入る" % [b["text"], a])
		for x in TouchPad.ALSO.get(a, []):
			check(Input.is_action_pressed(x), "%s を押すと %s も入る" % [b["text"], x])
		await touch(b["pos"], false)
		check(not Input.is_action_pressed(a), "%s を離すと %s が切れる" % [b["text"], a])

	## ボタンの外を押しても何も入らない。
	await touch(Vector2(320, 180), true)
	check(not _any_action(), "ボタンの外を押しても何も入らない")
	await touch(Vector2(320, 180), false)

	## 指をずらすと、ずらした先のボタンに移る。
	var up: Vector2 = _pos("up")
	var right: Vector2 = _pos("right")
	await touch(up, true)
	await drag(right)
	check(not Input.is_action_pressed("up") and Input.is_action_pressed("right"), "指をずらすと隣のボタンに移る")
	await touch(right, false)
	check(not _any_action(), "離すと全部切れる")

	## 二本の指で、歩きながら決められる。
	await touch(_pos("right"), true, 0)
	await touch(_pos("act"), true, 1)
	check(Input.is_action_pressed("right") and Input.is_action_pressed("act"), "二本指で右と決を同時に押せる")
	await touch(_pos("act"), false, 1)
	check(Input.is_action_pressed("right") and not Input.is_action_pressed("act"), "片方を離してももう片方は残る")
	await touch(_pos("right"), false, 0)

	## 場面が消えるとき、押したままのものを離す。
	await touch(_pos("left"), true)
	pad.queue_free()
	await process_frame
	check(not Input.is_action_pressed("left"), "消えるとき押しっぱなしを離す")

	## タイトルで、決 と 下 が本当に効くこと（is_action_just_pressed が拾う）。
	change_scene_to_file("res://scenes/title.tscn")
	await sleep(0.5)
	var title := current_scene
	check(title != null and title.name == "Title", "タイトルが開く")
	pad = TouchPad.new()
	title.add_child(pad)
	await process_frame
	await tap_button("down")
	check(title._sel == 1, "タイトルで 下 を押すと選択が動く")
	await tap_button("act")
	await sleep(0.2)
	check(title._screen == "stages", "タイトルで 決 を押すと決まる（ステージを選ぶ）")
	await tap_button("pause")
	await sleep(0.2)
	check(title._screen == "menu", "止 で戻る")

## 指からはマウスの左ボタンも作られるので、is_anything_pressed ではなく操作だけ見る。
func _any_action() -> bool:
	for b in TouchPad.BUTTONS:
		if Input.is_action_pressed(b["action"]):
			return true
	return false

func _pos(action: String) -> Vector2:
	for b in TouchPad.BUTTONS:
		if b["action"] == action:
			return b["pos"]
	return Vector2.ZERO

## ゲームの座標 p を画面の座標に直して、指を置く／離す。
func touch(p: Vector2, pressed: bool, finger := 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.position = root.get_screen_transform() * p
	ev.pressed = pressed
	ev.index = finger
	Input.parse_input_event(ev)
	await process_frame
	await process_frame

func drag(p: Vector2, finger := 0) -> void:
	var ev := InputEventScreenDrag.new()
	ev.position = root.get_screen_transform() * p
	ev.index = finger
	Input.parse_input_event(ev)
	await process_frame
	await process_frame

func tap_button(action: String) -> void:
	await touch(_pos(action), true)
	await touch(_pos(action), false)
