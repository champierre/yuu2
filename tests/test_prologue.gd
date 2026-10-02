extends "res://tests/helper.gd"
## タイトルの「物語のはじまり」で戻るを押すと、メニューに戻ること（#64）。
## 其の一は始まらない。もう一度選んで決定すれば始まる。

func _test() -> void:
	change_scene_to_file("res://scenes/title.tscn")
	await sleep(0.8)
	var title = current_scene
	title._choose_menu(0)
	await sleep(0.3)
	check(title._screen == "prologue", "始を選ぶと物語のはじまりが出る")

	## 物語が流れている途中でも、戻るでメニューへ戻れる。
	await tap("pause")
	await sleep(3.0)
	check(current_scene == title and title._screen == "menu", "戻るを押すとメニューに戻り、其の一は始まらない")
	var texts := []
	for c in title._panel.get_children():
		if c is Glyph and not c.is_queued_for_deletion():
			texts.append(c.text)
	check(not ("%s はじめる" % TouchPad.act_name()) in texts and texts.size() > 0 and "はじめる" not in str(texts), "メニューに「はじめる」の案内が紛れ込まない %s" % [texts])

	## 流れ終わったあとに戻るを押しても、メニューに戻る。
	title._choose_menu(0)
	await sleep(3.0)
	await tap("pause")
	await sleep(1.0)
	check(current_scene == title and title._screen == "menu", "流れ終わったあとでも、戻るでメニューに戻る")

	## もう一度選んで決定すると、其の一が始まる。
	title._choose_menu(0)
	await sleep(3.0)
	await tap("act")
	await sleep(1.5)
	check(current_scene != title and current_scene.has_method("number") and current_scene.number() == 1, "決定すると其の一が始まる")
