extends "res://tests/helper.gd"
## 其の四「灯」。淵の向こうの燭を火矢で灯すと、光の橋が現れる。

func _test() -> void:
	await open("res://scenes/stage4.tscn")
	var hero = stage.hero
	hero.max_hp = 99
	hero.hp = 99
	## 蝙が矢の通り道に入ると、燭より先に蝙に当たってしまう。
	clear_enemies()

	await face("right")
	check(await walk_to(cell(4, 17)), "宝箱の前へ")
	await face("right")
	await tap("act")
	check(hero.holding("弓"), "弓を取った")
	check(await walk_to(cell(2, 16)), "焚き火の前へ")
	await face("up")
	await tap("act")
	check(hero.holding("火") and hero.holding("弓"), "火と弓を持った")

	check(not stage.in_map(Vector2i(-1, 0)) and stage.solid_at(Vector2i(17, 6)) != 0, "はじめ橋は無い")
	## 淵の手前まで行き、向こう岸の燭を火矢で射る。
	check(await walk_path([cell(5, 16), cell(5, 11), cell(15, 11), cell(15, 5)]), "淵の手前まで歩ける")
	var candle = null
	for c in stage._candles:
		if stage.cell_of(c.position) == Vector2i(19, 5):
			candle = c
	## 遅いマシンでは狙いがずれることがあるので、3 回まで射ち直す。
	for i in 3:
		await walk_to(cell(15, 5))
		await face("right")
		print("    射る前: pos=%s facing=%s hands=%s mode=%s" % [hero.position, hero.facing, hero.hands, stage.mode])
		Input.action_press("act")
		await sleep(0.8)
		print("    溜め=%.2f time_scale=%.2f hp=%d fps=%d" % [stage._charge, Engine.time_scale, hero.hp, Engine.get_frames_per_second()])
		Input.action_release("act")
		await sleep(0.05)
		for n in stage.world.get_children():
			if n is Shot:
				print("    矢: pos=%s power=%.2f reach=%.0f fire=%s dead=%s" % [n.position, n.power, n.reach, n.fire, n.is_dead()])
		await sleep(0.55)
		if candle.get_meta("lit"):
			break
		print("    外れた（%d 回目）" % (i + 1))
	check(candle != null and candle.get_meta("lit"), "火矢で淵の向こうの燭が灯る")
	await sleep(0.1)
	check(stage.solid_at(Vector2i(17, 6)) == 0 and stage.solid_at(Vector2i(18, 6)) == 0, "光の橋が現れた")

	check(await walk_path([cell(15, 6), cell(20, 6), cell(30, 6), cell(30, 11), cell(29, 11)]), "橋を渡って奥へ")
	for i in 3:
		await walk_to(cell(29, 11))
		await face("down")
		await hold("act", 0.8)
		await sleep(0.6)
		if stage.solid_at(Vector2i(29, 12)) == 0:
			break
		print("    外れた（%d 回目） pos=%s facing=%s" % [i + 1, hero.position, hero.facing])
	check(stage.solid_at(Vector2i(29, 12)) == 0 and stage.solid_at(Vector2i(29, 13)) == 0, "二つめの光の橋")
	check(await walk_path([cell(30, 11), cell(30, 15), stage.goal().position], true), "目標まで歩ける")
	await sleep(0.2)
	check(stage.mode == "clear", "クリアした")
