extends "res://tests/helper.gd"
## 両手がふさがっているときに字を受け取ると、どれを置くかを聞く（#4）。
## 黙って古い方を落とさない。何を選んでも、字は消えずに足元に置かれる。

func _floor_items(k: String) -> int:
	var n := 0
	for g in stage.get_tree().get_nodes_in_group("item"):
		if g.text == k and not g.is_queued_for_deletion():
			n += 1
	return n

func _take_sun() -> void:
	stage.hero.position = cell(3, 9)
	await face("up")
	await tap("act")
	await sleep(0.2)

func _test() -> void:
	await open("res://scenes/stage6.tscn")
	await until(func(): return stage.mode == "talk", 3.0)
	await finish_talk()
	await until(func(): return stage.mode == "play", 3.0)
	var hero = stage.hero
	var hud = stage.hud
	hero.max_hp = 99
	hero.hp = 99
	hero.set_hands(["明", "弓"])

	## 日の祭壇で日を取ろうとすると、どれを置くか聞かれて止まる。
	await _take_sun()
	check(hud.has_method("is_choosing") and hud.is_choosing() and stage.get_tree().paused, "手がいっぱいだと、どれを置くか聞かれる")
	check(hero.hands == ["明", "弓"], "聞いている間は、手の字はそのまま")

	## そのまま決定すると（初めは「新しい字」）、日は足元に置かれ、手はそのまま。
	await sleep(0.3)
	await tap("act")
	await until(func(): return not stage.get_tree().paused, 2.0)
	check(hero.hands == ["明", "弓"], "決定を連打しても、明も弓も手放さない")
	check(_floor_items("日") == 1, "拾わなかった日は足元に置かれる")

	## もう一度取り、左の字（明）を選ぶと、明が足元に置かれて日を持つ。
	await _take_sun()
	await sleep(0.3)
	await tap("left")
	await tap("left")
	await tap("act")
	await until(func(): return not stage.get_tree().paused, 2.0)
	check(hero.holding("日") and hero.holding("弓") and not hero.holding("明"), "選んだ明を置いて、日を持つ")
	check(_floor_items("明") == 1, "置いた明は足元にあり、拾い直せる")
