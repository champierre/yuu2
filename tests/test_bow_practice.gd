extends "res://tests/helper.gd"
## 其の三は、蟲と戦う前に弓を試せること（#28）。
## - 弓を取っただけでも、穴の方へ行っただけでも、蟲は起きない
## - 宝箱のそばの的を、引き絞って射ると当たる（浅く引くと届かない）
## - 的と画面の反対側にある「射」の印から射て的に当てたときだけ、蟲が起きる
## - 岩に当たった矢は「カン」と弾く
## - 尾のことを教える旅人は、開始位置から宝箱へ向かう道の途中にいる

func _find(text: String) -> Glyph:
	for n in stage.world.get_children():
		if n is Glyph and n.text == text:
			return n
	return null

func _test() -> void:
	await open("res://scenes/stage3.tscn")
	var hero = stage.hero
	var start: Vector2 = hero.position
	var chest = null
	for c in stage.tiles:
		if stage.tiles[c].text == "宝箱":
			chest = stage.tiles[c]
	var traveler := _find("人")
	check(chest != null and traveler != null, "宝箱と旅人がいる")
	check(chest.position.distance_to(start) > 120.0, "宝箱は開始位置から離れた所にある")
	check(traveler.position.x < start.x and traveler.position.x > chest.position.x, "旅人は宝箱へ向かう道の途中にいる")

	check(await walk_route(stage.cell_of(chest.position) + Vector2i(1, 0)), "宝箱の前まで歩ける")
	await face("left")
	await tap("act")
	check(hero.holding("弓"), "宝箱から弓が出た")
	await sleep(0.5)
	check(not stage._awake, "弓を取っただけでは蟲は起きない")

	## 穴の方へ行っても、まだ蟲は起きない。
	var back: Vector2 = hero.position
	hero.position = stage.cell_center(Vector2i(12, 8))
	await sleep(0.6)
	check(not stage._awake, "的を射抜く前は、穴の方へ行っても蟲は起きない")
	hero.position = back

	## 近くから的に当てても、蟲は起きない。
	var target := _find("的")
	check(target != null, "的がある")
	var tc: Vector2i = stage.cell_of(target.position)
	hero.position = stage.cell_center(tc + Vector2i(0, 2))
	await face("up")
	await hold("act", 0.8)
	await sleep(0.6)
	check(target.get_meta("hits", 0) >= 1, "近くから射ても的には当たる")
	check(not stage._awake, "近くから当てても蟲は起きない")

	## 離れた所から浅く引くと届かない。
	var hits: int = target.get_meta("hits", 0)
	hero.position = stage.cell_center(tc + Vector2i(0, 4))
	await face("up")
	await hold("act", 0.15)
	await sleep(0.8)
	check(target.get_meta("hits", 0) == hits, "離れた所から浅く引いた矢は的に届かない")

	## 岩に当たった矢は「カン」と弾く。
	var clinks: int = stage._clinks
	var rock := Vector2i(9, 10)
	var keep: Vector2 = hero.position
	hero.position = stage.cell_center(rock + Vector2i(0, 2))
	await face("up")
	await hold("act", 0.5)
	await sleep(0.6)
	check(stage._clinks > clinks, "岩に当たった矢は弾かれる")
	check(not stage._awake, "岩を射ても蟲は起きない")

	## 「射」の印以外の所から当てても、蟲は起きない（離れた所からでも）。
	hero.position = keep
	await face("up")
	await hold("act", 0.8)
	await sleep(0.8)
	check(target.get_meta("hits", 0) > hits, "離れた所から引き絞った矢は的に当たる")
	check(not stage._awake, "「射」の印以外から当てても蟲は起きない")

	## 画面の反対側にある「射」の印から射て当てると、蟲が起きる。
	var mark := Vector2i(-1, -1)
	for n in stage.floor_layer.get_children():
		if n is Glyph and n.text == "射":
			mark = stage.cell_of(n.position)
	check(mark.x > 18 and mark.y == tc.y, "「射」の印は、的と同じ段の反対側の端にある（%s）" % mark)
	check(await walk_route(mark), "「射」の印まで歩ける")
	await face("left")
	var h2: int = target.get_meta("hits", 0)
	await hold("act", 0.9)
	await until(func(): return stage._awake, 4.0)
	check(target.get_meta("hits", 0) > h2, "「射」の印から引き絞った矢は、岩に当たらず的まで届く")
	check(stage._awake, "「射」の印から的に当てると、蟲が起きる")
