extends Node2D
## エンディング。物語の結びと、遊んだ記録、作った人。

const INK := Color("#1f1a16")
const RED := Color("#b8322a")
const SUB := Color("#6b6259")
const PAPER := Color("#f6f0e2")

var _roll: Node2D
var _done := false
var _speed := 26.0

func _ready() -> void:
	Sfx.bgm("ending")
	_roll = Node2D.new()
	add_child(_roll)
	var total := 0.0
	for no in Game.cleared:
		total += float(Game.cleared[no])
	var lines := [
		["闇は晴れ、字の国に光が戻った。", INK, 16],
		["ばらばらだった字は、ふたたび合わさり、", INK, 16],
		["人々は、また言葉を交わしはじめた。", INK, 16],
		["", INK, 30],
		["勇", INK, 110],
		["", INK, 30],
		["勇とは、甬（おけ）に力を注ぐこと。", SUB, 14],
		["力を合わせて、字を合わせて、ここまで来た。", SUB, 14],
		["", INK, 40],
		["― 旅の記録 ―", RED, 16],
		["字典　%d / %d" % [Game.discovered.size(), Kanji.DEX_ORDER.size()], INK, 15],
		["倒れた回数　%d" % Game.deaths, INK, 15],
		["かかった時間（最速の合計）　%s" % Stage.fmt_time(total), INK, 15],
		["", INK, 40],
		["― 原作 ―", RED, 16],
		["漢字謎解きアクション「勇」の冒険", INK, 14],
		["「勇」の冒険 2", INK, 14],
		["（Scratch 版　作: jishiha）", SUB, 13],
		["", INK, 30],
		["― 字 ―", RED, 16],
		["Noto Sans JP（SIL Open Font License）", SUB, 13],
		["", INK, 50],
		["終", INK, 34],
	]
	var y := 400.0
	for l in lines:
		var g := Glyph.make(l[0], l[1], l[2])
		g.position = Vector2(320, y)
		g.shadow = l[2] > 30
		g.outline = 4
		g.outline_color = PAPER
		_roll.add_child(g)
		y += l[2] + 14
	_roll.set_meta("end", y)
	if TouchPad.needed():
		add_child(TouchPad.new())
	if Game.discovered.size() < Kanji.DEX_ORDER.size():
		var hint := Glyph.make("まだ見つけていない字がある。ステージを選んで探してみよう", SUB, 11)
		hint.shadow = false
		hint.position = Vector2(320, 346)
		hint.modulate.a = 0.0
		hint.set_meta("late", true)
		add_child(hint)

func _process(delta: float) -> void:
	var fast := Input.is_action_pressed("act") or Input.is_action_pressed("ui_accept")
	if not _done:
		_roll.position.y -= _speed * delta * (4.0 if fast else 1.0)
		var end: float = _roll.get_meta("end")
		if _roll.position.y + end < 230.0:
			_done = true
			for c in get_children():
				if c.has_meta("late"):
					c.create_tween().tween_property(c, "modulate:a", 1.0, 0.8)
			var go := Glyph.make("%s タイトルへ" % TouchPad.act_name(), RED, 14)
			go.position = Vector2(320, 318)
			go.shadow = false
			add_child(go)
			var tw := go.create_tween().set_loops()
			tw.tween_property(go, "modulate:a", 0.3, 0.5)
			tw.tween_property(go, "modulate:a", 1.0, 0.5)
		return
	if Input.is_action_just_pressed("act") or Input.is_action_just_pressed("ui_accept"):
		Sfx.play("confirm")
		Game.goto_title()
