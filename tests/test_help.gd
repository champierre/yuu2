extends "res://tests/helper.gd"
## 「遊び方」の画面が、謎の答え（ゲームで作る字の合わせ方）を教えないこと。
## 其の一で教わる斧だけは出してよい。

func _test() -> void:
	change_scene_to_file("res://scenes/title.tscn")
	await sleep(0.6)
	var title = current_scene
	title._show_help()
	await sleep(0.2)
	var shown := []
	for c in title._panel.get_children():
		if c is Glyph and not c.is_queued_for_deletion():
			shown.append(c.text)
	var spoiled := []
	for k in Kanji.RECIPES.values():
		if k == "斧":
			continue
		for t in shown:
			if ("＝" + k) in t:
				spoiled.append("%s（%s）" % [k, t])
	check(spoiled.is_empty(), "遊び方に謎の答えが書かれていない %s" % [spoiled])
