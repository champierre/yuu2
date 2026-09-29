extends "res://tests/helper.gd"
## デバッグモード。どのステージでも選べて、ステージの中からも飛べる。

func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await process_frame

func _test() -> void:
	var game = root.get_node("Game")

	## 起動のしかたで決まる。
	## エディタの ▶ から起動すると、エディタのデバッガがつながる。
	## （エディタが付ける --remote-debug は、エンジンが取り除くので引数には残らない）
	check(game.debug_from(["debug=true"], false), "-- debug=true でデバッグになる")
	check(game.debug_from([], true), "エディタから起動する（デバッガがつながる）とデバッグになる")
	check(not game.debug_from([], false), "ふつうに起動したときはデバッグにならない")

	## ふつうのときは、クリアしたところまでしか選べない。
	game.debug = false
	check(game.unlocked_max() == 1, "ふつうは其の一しか選べない")

	## ステージの中で数字キーを押しても、ふつうは何も起きない。
	await open("res://scenes/stage1.tscn")
	await _key(KEY_3)
	await sleep(1.5)
	check(current_scene.number() == 1, "ふつうは数字キーでステージを移れない")

	game.debug = true
	check(game.unlocked_max() == game.STAGES.size(), "デバッグなら全部のステージを選べる")

	## ステージの中から、数字キーで好きなステージへ飛べる。
	await _key(KEY_3)
	await sleep(1.5)
	check(current_scene.has_method("number") and current_scene.number() == 3, "3 を押すと其の三へ飛ぶ")
	stage = current_scene
	await until(func(): return stage.mode == "play", 3.0)
	check(stage.hud.has_debug_badge(), "ステージの中にデバッグの印が出る")

	## N でクリア扱いにできる。
	await _key(KEY_N)
	await sleep(0.3)
	check(stage.mode == "clear", "N を押すとクリア扱いになる")

	## タイトルのステージ選びで、まだクリアしていないステージも選べる。
	change_scene_to_file("res://scenes/title.tscn")
	await sleep(0.8)
	var title = current_scene
	check(title.has_debug_badge(), "タイトルにデバッグの印が出る")
	title._sel = 1
	title._choose_menu(1)
	title._sel = 5
	title._choose_stage(5)
	await sleep(1.5)
	check(current_scene.has_method("number") and current_scene.number() == 6, "タイトルから終の章を選べる")
	game.debug = false
