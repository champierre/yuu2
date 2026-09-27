extends Node2D
## タイトル。はじめから・ステージを選ぶ・字典・遊び方。

const INK := Color("#1f1a16")
const RED := Color("#b8322a")
const SUB := Color("#6b6259")
const PAPER := Color("#f6f0e2")

const MENU := ["はじめから", "ステージを選ぶ", "字典", "遊び方"]
const DRIFT := "木川山火日月金土水人口田石竹花鳥門光"

const PROLOGUE := [
	"むかしむかし、字の国に「魔」があらわれた。",
	"魔は、世の字をばらばらにして、国を闇でおおった。",
	"勇者「勇」は旅に出る。",
	"ばらばらの字を拾い、合わせ直しながら――",
]

## "menu" / "stages" / "dex" / "help" / "prologue"
var _screen := "menu"
var _sel := 0
var _items: Array[Glyph] = []
var _panel: Node2D
var _big: Glyph
var _t := 0.0
var _busy := false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#f3ecdc"))
	_build_drift()
	_big = Glyph.make("勇", INK, 150)
	_big.position = Vector2(170, 170)
	_big.outline = 10
	_big.outline_color = PAPER
	add_child(_big)
	var title := Glyph.make("「勇」の冒険", INK, 30)
	title.position = Vector2(170, 292)
	title.outline = 5
	title.outline_color = PAPER
	add_child(title)
	var sub := Glyph.make("〜 漢字錬成 〜", RED, 16)
	sub.position = Vector2(170, 324)
	sub.shadow = false
	add_child(sub)
	## 大きな字を、墨で書くように現す。
	_big.squash = Vector2(0.6, 0.6)
	_big.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_big, "modulate:a", 1.0, 0.5)
	tw.tween_property(_big, "squash", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_panel = Node2D.new()
	add_child(_panel)
	if TouchPad.needed():
		add_child(TouchPad.new())
	_show_menu()
	Sfx.bgm("title")
	Sfx.prepare("field")

func _build_drift() -> void:
	for i in 26:
		var g := Glyph.make(DRIFT[i % DRIFT.length()], Color(0.45, 0.38, 0.3, randf_range(0.06, 0.14)), randi_range(18, 44))
		g.shadow = false
		g.position = Vector2(randf() * 640, randf() * 360)
		g.set_meta("v", Vector2(randf_range(-6, 6), randf_range(-12, -4)))
		g.set_meta("spin", randf_range(-0.3, 0.3))
		g.z_index = -5
		g.add_to_group("drift")
		add_child(g)

func _process(delta: float) -> void:
	_t += delta
	for g in get_tree().get_nodes_in_group("drift"):
		var gg: Glyph = g
		gg.position += gg.get_meta("v") * delta
		gg.tilt += gg.get_meta("spin") * delta
		if gg.position.y < -30:
			gg.position = Vector2(randf() * 640, 390)
	_big.tilt = sin(_t * 0.8) * 0.02
	if _busy or Game.is_changing():
		return
	match _screen:
		"menu":
			_input_list(MENU.size(), _choose_menu)
		"stages":
			_input_list(Game.STAGES.size(), _choose_stage)
		"dex":
			_input_dex()
		"help", "prologue":
			if _accept() or _back():
				if _screen == "prologue":
					_start_game()
				else:
					Sfx.play("select")
					_show_menu()

func _accept() -> bool:
	return Input.is_action_just_pressed("act") or Input.is_action_just_pressed("ui_accept")

func _back() -> bool:
	return Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("ui_cancel")

func _input_list(n: int, choose: Callable) -> void:
	if Input.is_action_just_pressed("ui_down"):
		_sel = (_sel + 1) % n
		Sfx.play("select")
		_refresh_list()
	elif Input.is_action_just_pressed("ui_up"):
		_sel = (_sel + n - 1) % n
		Sfx.play("select")
		_refresh_list()
	elif _accept():
		choose.call(_sel)
	elif _back() and _screen != "menu":
		Sfx.play("select")
		_show_menu()

func _clear_panel() -> void:
	for c in _panel.get_children():
		c.queue_free()
	_items.clear()

func _label(t: String, pos: Vector2, col := INK, size := 16, bold := false) -> Glyph:
	var g := Glyph.make(t, col, size)
	g.bold = bold
	g.shadow = false
	g.position = pos
	g.outline = 4
	g.outline_color = PAPER
	_panel.add_child(g)
	return g

# ---------------------------------------------------------------- メニュー

func _show_menu() -> void:
	_screen = "menu"
	_clear_panel()
	_sel = clampi(_sel, 0, MENU.size() - 1)
	for i in MENU.size():
		_items.append(_label(MENU[i], Vector2(470, 120 + i * 42), INK, 20, true))
	var dex := "字典　%d / %d" % [Game.discovered.size(), Kanji.DEX_ORDER.size()]
	_label(dex, Vector2(470, 300), SUB, 12)
	_label("%s 選ぶ　%s 決める" % ["上下" if TouchPad.needed() else "↑↓", TouchPad.act_name()], Vector2(470, 336), SUB, 11)
	_refresh_list()

func _refresh_list() -> void:
	for i in _items.size():
		var g := _items[i]
		var base: String = g.get_meta("base", g.text)
		g.set_meta("base", base)
		var on := i == _sel
		g.text = ("▶ " + base) if on else base
		g.color = RED if on else INK
		if on:
			Fx.pop(g, 0.15)

func _choose_menu(i: int) -> void:
	Sfx.play("confirm")
	match i:
		0:
			_show_prologue()
		1:
			_sel = 0
			_show_stages()
		2:
			_sel = 0
			_show_dex()
		3:
			_show_help()

# ---------------------------------------------------------------- 物語のはじまり

func _show_prologue() -> void:
	_screen = "prologue"
	_clear_panel()
	_busy = true
	for i in PROLOGUE.size():
		var g := _label(PROLOGUE[i], Vector2(470, 110 + i * 34), INK, 13)
		g.modulate.a = 0.0
		var tw := g.create_tween()
		tw.tween_interval(i * 0.6)
		tw.tween_property(g, "modulate:a", 1.0, 0.5)
	await get_tree().create_timer(0.6 * PROLOGUE.size()).timeout
	if not is_inside_tree():
		return
	var go := _label("%s はじめる" % TouchPad.act_name(), Vector2(470, 280), RED, 14, true)
	var tw2 := go.create_tween().set_loops()
	tw2.tween_property(go, "modulate:a", 0.3, 0.5)
	tw2.tween_property(go, "modulate:a", 1.0, 0.5)
	_busy = false

func _start_game() -> void:
	Sfx.play("confirm")
	_busy = true
	Game.goto_stage(1)

# ---------------------------------------------------------------- ステージを選ぶ

func _show_stages() -> void:
	_screen = "stages"
	_clear_panel()
	var top := Game.unlocked_max()
	for i in Game.STAGES.size():
		var s: Dictionary = Game.STAGES[i]
		var open: bool = s["no"] <= top
		var t := "%s「%s」" % [s["name"], s["kanji"]] if open else "%s「？」" % s["name"]
		var g := _label(t, Vector2(450, 70 + i * 38), INK if open else SUB, 17, true)
		_items.append(g)
		if Game.cleared.has(s["no"]):
			var st := _label("達成 %s" % Stage.fmt_time(Game.cleared[s["no"]]), Vector2(580, 70 + i * 38), RED, 10)
			st.bold = true
	_label("%s 戻る" % TouchPad.pause_name(), Vector2(470, 336), SUB, 11)
	_refresh_list()

func _choose_stage(i: int) -> void:
	var s: Dictionary = Game.STAGES[i]
	if s["no"] > Game.unlocked_max():
		Sfx.play("fail")
		Fx.shake(_items[i], 4.0)
		return
	Sfx.play("confirm")
	_busy = true
	Game.goto_stage(s["no"])

# ---------------------------------------------------------------- 字典

var _dex_cells: Array[Glyph] = []
var _dex_info: Array[Glyph] = []

func _show_dex() -> void:
	_screen = "dex"
	_clear_panel()
	_dex_cells.clear()
	var bg := _Sheet.new()
	bg.rect = Rect2(330, 40, 290, 290)
	_panel.add_child(bg)
	_label("字典　%d / %d" % [Game.discovered.size(), Kanji.DEX_ORDER.size()], Vector2(475, 62), INK, 16, true)
	for i in Kanji.DEX_ORDER.size():
		var k: String = Kanji.DEX_ORDER[i]
		var known := Game.discovered.has(k)
		var pos := Vector2(372 + (i % 5) * 52, 110 + (i / 5) * 58)
		var g := _label(k if known else "？", pos, INK if known else Color(0.6, 0.55, 0.5), 30, true)
		_dex_cells.append(g)
	_dex_info = [
		_label("", Vector2(475, 236), RED, 18, true),
		_label("", Vector2(475, 262), SUB, 13),
		_label("", Vector2(475, 290), INK, 11),
	]
	_label("%s 戻る" % TouchPad.pause_name(), Vector2(470, 344), SUB, 11)
	_refresh_dex()

class _Sheet extends Node2D:
	var rect := Rect2()
	func _draw() -> void:
		draw_rect(rect, Color(1, 1, 1, 0.45))
		draw_rect(rect, Color(0.12, 0.1, 0.09, 0.6), false, 1.5)

func _refresh_dex() -> void:
	for i in _dex_cells.size():
		var g := _dex_cells[i]
		g.outline_color = Color("#f0c8b0") if i == _sel else PAPER
		g.outline = 8 if i == _sel else 4
	var k: String = Kanji.DEX_ORDER[_sel]
	if Game.discovered.has(k):
		var info: Dictionary = Kanji.INFO[k]
		_dex_info[0].text = "%s ＝ %s" % [k, Kanji.formula(k)]
		_dex_info[1].text = "「%s」" % info["yomi"]
		_dex_info[2].text = info["desc"]
	else:
		_dex_info[0].text = "？"
		_dex_info[1].text = "まだ見つけていない字"
		_dex_info[2].text = "ステージのどこかで、字を合わせると見つかる"

func _input_dex() -> void:
	var n := _dex_cells.size()
	var moved := false
	if Input.is_action_just_pressed("ui_right"):
		_sel = (_sel + 1) % n
		moved = true
	elif Input.is_action_just_pressed("ui_left"):
		_sel = (_sel + n - 1) % n
		moved = true
	elif Input.is_action_just_pressed("ui_down"):
		_sel = (_sel + 5) % n
		moved = true
	elif Input.is_action_just_pressed("ui_up"):
		_sel = (_sel + n - 5) % n
		moved = true
	elif _back() or _accept():
		Sfx.play("select")
		_sel = 2
		_show_menu()
		return
	if moved:
		Sfx.play("select")
		_refresh_dex()

# ---------------------------------------------------------------- 遊び方

func _show_help() -> void:
	_screen = "help"
	_clear_panel()
	var bg := _Sheet.new()
	bg.rect = Rect2(320, 30, 305, 305)
	_panel.add_child(bg)
	var touch := TouchPad.needed()
	var lines := [
		["遊び方", RED, 18],
		["%s　歩く" % ("上下左右" if touch else "↑↓←→"), INK, 13],
		["%s　拾う・話す・調べる・使う" % TouchPad.act_name(), INK, 13],
		["%s　両手の字を合わせる" % TouchPad.craft_name(), INK, 13],
		["%s　一時停止" % TouchPad.pause_name(), INK, 13],
		["", INK, 8],
		["両手に 1 つずつ、字を持てる。", SUB, 12],
		["二つの字を合わせると、新しい字になる。", SUB, 12],
		["父＋斤＝斧　金＋失＝鉄　日＋月＝明……", SUB, 12],
		["弓は %s を長押しで引き絞り、離して射る。" % TouchPad.act_name(), SUB, 12],
		["困ったら、字をよく見ること。", RED, 12],
	]
	for i in lines.size():
		var l: Array = lines[i]
		_label(l[0], Vector2(472, 58 + i * 25), l[1], l[2], i == 0)
	_label("%s 戻る" % TouchPad.act_name(), Vector2(470, 348), SUB, 11)
