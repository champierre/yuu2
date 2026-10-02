extends "res://tests/helper.gd"
## 其の四の蝙は、真っ暗な所では姿が見えない。そのかわり、目だけが光って気配が分かること（#2）。
## 目は闇より手前の層（glow_layer）に置き、蝙について動き、蝙を倒せば消える。

func _test() -> void:
	await open("res://scenes/stage4.tscn")
	var bats := stage.get_tree().get_nodes_in_group("enemy")
	check(bats.size() > 0, "蝙がいる")
	var ok := true
	for b in bats:
		var eyes = b.get("eyes")
		if eyes == null or not is_instance_valid(eyes) or eyes.get_parent() != stage.glow_layer():
			ok = false
	check(ok, "どの蝙にも、闇より手前に光る目がある")

	var b = bats[0]
	b.position += Vector2(30, 0)
	await sleep(0.1)
	check(b.eyes.global_position.distance_to(b.global_position) < 8.0, "目は蝙について動く")

	var eyes = b.eyes
	b.die()
	await sleep(0.1)
	check(not is_instance_valid(eyes), "蝙を倒すと目も消える")
