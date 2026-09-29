extends "res://tests/helper.gd"
## ステージ4 の暗がり。明かりの無い所は真っ暗で、蝙の動きも見えないこと。
## うっすら透けていると、燭を灯さなくても敵の居場所が分かってしまう。

func _test() -> void:
	await open("res://scenes/stage4.tscn")
	var dark = stage.dark
	var bats := 0
	var seen := []
	for e in stage.get_tree().get_nodes_in_group("enemy"):
		var p: Vector2 = e.global_position
		## 明かり（焚き火・勇者の手元・目標）の届かない所にいる蝙だけを見る。
		if stage.light_at(p) > 0.0:
			continue
		bats += 1
		var a: float = dark.opacity(stage.light_at(p))
		if a < 1.0:
			seen.append("%s（墨の濃さ %.2f）" % [p, a])
	check(bats > 0, "暗がりに蝙がいる")
	check(seen.is_empty(), "暗がりの蝙はまったく見えない %s" % [seen])

	## 明かりの中は、ちゃんと見える。
	var near: Vector2 = stage.hero.global_position
	check(dark.opacity(stage.light_at(near)) < 0.1, "勇者の足元は見える")
