extends "res://tests/helper.gd"
## 其の四の燭まわり（#20）。
## - 灯っていない燭は、暗がりでも在りかが分かる（闇より手前に目印がある）
## - 火矢は小さな明かりを持って飛ぶ。ただし火矢の明かりでは橋は出ない
## - 左上の燭のそばには隠しの「丁」があり、灯す意味がある

func _candle_at(c: Vector2i) -> Glyph:
	for g in stage._candles:
		if stage.cell_of(g.position) == c:
			return g
	return null

func _test() -> void:
	await open("res://scenes/stage4.tscn")
	clear_enemies()
	var hero = stage.hero

	## 灯っていない燭には、闇より手前に目印がある。
	var ok := true
	for g in stage._candles:
		var mark = g.get_meta("mark", null)
		if mark == null or not is_instance_valid(mark) or mark.get_parent() != stage.glow_layer():
			ok = false
	check(ok, "灯っていない燭は、暗がりでも在りかが分かる")

	## 火矢は明かりを持って飛ぶが、淵を越えても橋は出ない。
	hero.position = cell(16, 6)
	hero.set_hands(["弓", "火"])
	hero.facing = Vector2.RIGHT
	var s = stage.fire_arrow(1.0)
	await sleep(0.02)
	var lit := false
	for l in stage._lights:
		if l["node"] == s:
			lit = true
	check(lit, "火矢は小さな明かりを持って飛ぶ")
	var bridged := false
	for i in 20:
		if stage.solid_at(Vector2i(17, 6)) == 0:
			bridged = true
		await sleep(0.02)
	check(not bridged, "火矢の明かりでは、橋は出ない")

	## 燭を灯すと、目印は消える。
	var first := _candle_at(Vector2i(19, 5))
	stage._light_candle(first)
	await sleep(0.1)
	var mark = first.get_meta("mark", null)
	check(mark == null or not is_instance_valid(mark) or not mark.visible, "灯った燭の目印は消える")

	## 左上の燭のそばに、隠しの丁がある。
	var corner := _candle_at(Vector2i(3, 2))
	var near := false
	for g in stage.get_tree().get_nodes_in_group("item"):
		if g.text == "丁" and g.position.distance_to(corner.position) < stage.LAMP_R * 0.6:
			near = true
	check(near, "左上の燭を灯すと照らされる所に、隠しの丁がある")
