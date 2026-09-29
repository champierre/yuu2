extends "res://tests/helper.gd"
## 合わせた字の札。どの字の説明も、札の枠からはみ出さないこと。

func _test() -> void:
	await open("res://scenes/stage1.tscn")
	var hud = stage.hud
	for k in Kanji.DEX_ORDER:
		hud.card(k, true)
		await sleep(0.5)
		var panel: Rect2 = Rect2()
		var inside := true
		var detail := ""
		for c in hud._card.get_children():
			if c.is_queued_for_deletion():
				continue
			## 札の地（Hud._Panel）。型名は --script モードでは使えないので、字でも文でもないもので見分ける。
			if not (c is Glyph) and not (c is Label):
				panel = c.rect
		for c in hud._card.get_children():
			if c.is_queued_for_deletion():
				continue
			var r := Rect2()
			if c is Label:
				var font: Font = c.get_theme_font("font")
				var fs: int = c.get_theme_font_size("font_size")
				## 実際に描かれる文字の幅（折り返した後の各行のうち、いちばん長いもの）。
				var text_size: Vector2 = font.get_multiline_string_size(c.text, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, fs, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_GRAPHEME_BOUND)
				r = Rect2(c.position + Vector2((c.size.x - text_size.x) * 0.5, 0), text_size)
				## 最後の行の下の端が、枠の線（内側の飾り線 4px）より上にあること。
				var bottom: float = c.position.y + c.get_line_count() * c.get_line_height()
				if c.size.x > panel.size.x - 20 or bottom > panel.end.y - 5.0:
					inside = false
					detail += " %s: 幅 %.0f 行 %d 下端 %.0f" % [k, c.size.x, c.get_line_count(), bottom]
			elif c is Glyph and c.text != "":
				var b: Vector2 = c.box()
				r = Rect2(c.position - b * 0.5, b)
			else:
				continue
			if not panel.grow(1.0).encloses(r):
				inside = false
				detail += " %s:「%s」%s" % [k, c.text if not (c is Label) else "説明", r]
		check(inside, "「%s」の札は枠に収まる%s" % [k, detail])
		hud._card_showing = false
		stage.get_tree().paused = false

	## 会話の吹き出しも、長いせりふが枠の中で折り返されること。
	var long := "足手まといでなければ、わたしも連れていってください。木陰で休めれば、元気が出るのですが。"
	hud.talk([["人", long]])
	## 文字を 1 字ずつ出している間は、出た分だけで行を数えるので、出しきるまで待つ。
	await sleep(2.5)
	var dl: Label = hud._dialog_label
	var box_bottom := 262.0 + 84.0
	check(dl.size.x <= 520.0 and dl.get_line_count() >= 2, "長いせりふは折り返される（幅 %.0f 行 %d）" % [dl.size.x, dl.get_line_count()])
	check(dl.position.y + dl.get_line_count() * 21.0 <= box_bottom, "せりふが吹き出しの下にはみ出さない")
