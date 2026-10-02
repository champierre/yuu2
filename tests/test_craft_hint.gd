extends "res://tests/helper.gd"
## 右上の「合わせる」の案内が、まだ作ったことのない字の答えを教えないこと（#1）。
## 合わせられる組み合わせでも、合わない組み合わせでも、同じ案内になる。
## 一度作った字だけは、何ができるかを出してよい。

func _hint(hands: Array) -> String:
	stage.hero.set_hands(hands)
	stage._refresh_hud()
	return stage.hud._craft_hint.text

func _test() -> void:
	await open("res://scenes/stage2.tscn")
	var game = root.get_node("Game")
	game.discovered.erase("鉄")

	var good := _hint(["金", "失"])
	var bad := _hint(["金", "火"])
	check(good == bad, "合わせられる組でも合わない組でも、同じ案内になる（「%s」と「%s」）" % [good, bad])
	check(good != "", "両手に字があれば、合わせられることは案内する")
	check(_hint(["金"]) == "", "片手のときは出さない")

	game.discovered["鉄"] = true
	check("鉄" in _hint(["金", "失"]), "一度作った字なら、何ができるかを出す")
	game.discovered.erase("鉄")
