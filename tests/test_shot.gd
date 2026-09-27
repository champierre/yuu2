extends "res://tests/helper.gd"
## 矢は、立ち位置が数 px ずれても、同じ的に当たること。
##
## 燭は壁と同じ「通れないマス」にある。矢の中心がそのマスに入った瞬間に
## 壁として消えてしまい、立ち位置によっては燭に火が移らなかった
## （CI の遅いマシンでだけ外れていた）。

func _test() -> void:
	await open("res://scenes/stage4.tscn")
	clear_enemies()
	var candle = null
	for c in stage._candles:
		if stage.cell_of(c.position) == Vector2i(19, 5):
			candle = c
	var missed := []
	for i in 20:
		var x := 372.0 + i * 0.5
		## 燭を消えた状態に戻す。
		candle.set_meta("lit", false)
		candle.add_to_group("shootable")
		var s = Shot.new()
		s.stage = stage
		s.text = "矢"
		s.fire = true
		s.dir = Vector2.RIGHT
		s.speed = 520.0
		s.reach = 430.0
		s.position = Vector2(x + 14.0, candle.position.y)
		stage.world.add_child(s)
		await sleep(0.4)
		if not candle.get_meta("lit"):
			missed.append(x)
	check(missed.is_empty(), "どこから射ても燭に当たる（外れた位置 %s）" % [missed])
