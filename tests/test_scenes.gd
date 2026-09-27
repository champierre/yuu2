extends "res://tests/helper.gd"
## タイトル・エンディングと全ステージが、エラーなく開けること。
## ステージを選んで入り、一時停止からタイトルへ戻れること。

func _test() -> void:
	change_scene_to_file("res://scenes/title.tscn")
	await sleep(0.5)
	check(current_scene != null and current_scene.name == "Title", "タイトルが開く")
	for s in root.get_node("Game").STAGES:
		change_scene_to_file(s["scene"])
		await sleep(1.0)
		check(current_scene != null and current_scene.has_method("number") and current_scene.number() == s["no"], "%s「%s」が開く" % [s["name"], s["kanji"]])
	## 一時停止からタイトルへ。
	stage = current_scene
	await until(func(): return stage.mode == "play" or stage.mode == "talk", 3.0)
	await finish_talk()
	await until(func(): return stage.mode == "play", 3.0)
	await tap("pause")
	check(stage.get_tree().paused, "一時停止できる")
	await tap("down")
	await tap("down")
	await tap("act")
	await sleep(1.5)
	check(current_scene != null and current_scene.name == "Title" and not paused, "一時停止からタイトルへ戻れる")
	change_scene_to_file("res://scenes/ending.tscn")
	await sleep(0.5)
	check(current_scene != null and current_scene.name == "Ending", "エンディングが開く")
