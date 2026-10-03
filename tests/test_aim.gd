extends "res://tests/helper.gd"
## 向きの印（#38）。
## 向いている方の三角は、「勇」の字や手の字に隠れない所に、それらより手前に出る。
## 弓を引き絞っている間は、矢が届く所まで点線の照準が伸びる。

const DIRS := [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1),
	Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1)]

func _test() -> void:
	await open("res://scenes/stage1.tscn")
	clear_enemies()
	var hero = stage.hero
	var aim = hero.aim()
	hero.set_hands(["明", "弓"])
	await process_frame

	## 手の字より手前に描く。闇より手前の層にあるので、世界のもの（勇・手の字）より上になる。
	check(aim.get_parent() == stage.glow_layer(), "向きの印は、手の字より手前の層にある")

	## 8 方向とも、三角は「勇」の字の外にあり、向いている方を指す。
	var outside := true
	var pointing := true
	var off_hands := true
	for d in DIRS:
		hero.facing = hero._snap8(d)
		## 手の字がよけ終わるのを待つ。
		await sleep(0.4)
		var tri: PackedVector2Array = aim.triangle()
		## 三角のどの角も、手の字（縁取りぶんを足した枠）に掛からない。
		for k in ["明", "弓"]:
			var g = hero.hand_glyph(k)
			var box := Rect2(g.position - g.box() * 0.5, g.box()).grow(2.0)
			for p in tri:
				if box.has_point(p):
					off_hands = false
		for p in tri:
			## 「勇」は 22px の字。真ん中から角までは 15.6px。
			if p.length() < 16.0:
				outside = false
		if tri[0].normalized().dot(hero.facing.normalized()) < 0.999 or tri[0].length() < 24.0:
			pointing = false
	check(outside, "どの向きでも、三角は「勇」の字の外に出ている")
	check(off_hands, "どの向きでも、三角は手の字に重ならない（斜め上では手の字が下がる）")
	check(pointing, "どの向きでも、三角の先は向いている方を指す")

	## 勇者について動く。
	hero.position += Vector2(30, 0)
	await process_frame
	await process_frame
	check(aim.global_position.is_equal_approx(hero.global_position), "向きの印は、勇者について動く")

	## 引き絞っていないときは、照準は出ない。
	check(is_zero_approx(hero.aim_reach) and aim.dots().is_empty(), "引き絞っていないときは、照準は出ない")

	## 弓を引き絞ると、照準が伸びていく。放すと消える。
	hero.position = cell(8, 9)
	hero.facing = Vector2.UP
	await process_frame
	Input.action_press("act")
	await sleep(0.25)
	var early: float = hero.aim_reach
	var early_dots: int = aim.dots().size()
	check(early > 0.0, "引き絞り始めると、照準が出る")
	await sleep(0.9)
	var full: float = hero.aim_reach
	check(full > early and aim.dots().size() >= early_dots, "引き絞るほど、照準が伸びる")
	check(is_equal_approx(full, stage.ARROW_START + stage.arrow_reach(1.0)), "引き絞りきると、矢が届く距離になる")
	## 点は向いている方へまっすぐ並び、矢が止まる壁の中には打たない。
	var straight := true
	var clear := true
	for p in aim.dots():
		if p.normalized().dot(hero.facing.normalized()) < 0.999:
			straight = false
		if stage.shot_blocked(hero.global_position + p):
			clear = false
	check(straight, "照準は、向いている方へまっすぐ伸びる")
	check(clear, "照準は、矢が止まる壁の手前で止まる")
	var last: Vector2 = aim.dots()[-1]
	check(last.length() < full - aim.DOT_STEP, "壁があるので、届く距離いっぱいまでは伸びない")
	Input.action_release("act")
	await sleep(0.2)
	check(is_zero_approx(hero.aim_reach) and aim.dots().is_empty(), "放すと、照準は消える")

	## 倒れたら、印は消える。
	hero.hp = 0
	await process_frame
	await process_frame
	check(not aim.visible, "倒れたら、向きの印は出さない")
