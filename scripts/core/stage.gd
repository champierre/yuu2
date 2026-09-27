class_name Stage
extends Node2D
## ステージの土台。どのステージでも同じことをする部分をまとめる。
##
## - 漢字で書いた地図を読んで並べる（山・川・木・壁…）
## - 拾う・開ける・話す・読む（近くのものを Z で）
## - 両手の字を合わせる（X）、持っている字を使う（Z）
## - 弓を引き絞って射る（弓を持っているとき Z 長押し）
## - 命・倒れる・クリア・一時停止
##
## ステージごとの中身は、これを継承して _build() と各 on_*() に書く。

const CELL := 24
const INK := Color("#1f1a16")
const COL_MOUNTAIN := Color("#6f655a")
const COL_ROCK := Color("#857b6f")
const COL_WALL := Color("#8a5a3c")
const COL_WATER := Color("#3a7cc0")
const COL_TREE := Color("#3f8a3a")
const COL_GRASS := Color("#a9c48a")
const COL_FLOWER := Color("#d98aa0")
const COL_CHEST := Color("#bb3023")
const COL_EMPTY := Color("#a09488")
const COL_SIGN := Color("#8a6a45")
const COL_ARROW := Color("#5a4632")
const COL_FIRE := Color("#e0561b")

## 地形の種類。0 は何も無い。
const FREE := 0
const WALL := 1    ## 歩けない・矢も止まる
const WATER := 2   ## 歩けない・矢は越える
const PLANT := 3   ## 植えた林・森。歩けない・矢も止まる・見張りの目もさえぎる

## 近くのものに手が届く広さ。
const REACH := 10.0
## 弓を引き絞りきるまでの秒数。
const CHARGE_TIME := 0.7

## 持っている字を使うときに、どれを先に使うか。
const USE_ORDER := ["弓", "炎", "斧", "休", "星", "鳴", "森", "林", "灯", "明"]

var cols := 0
var rows := 0
var _solid := PackedByteArray()
var tiles := {}        ## Vector2i -> Glyph
var world: Node2D
var floor_layer: Node2D
var hero: Hero
var hud: Hud
var cam: Camera2D
var dark: Dark = null

## "cut"（演出中）/ "play" / "talk" / "clear" / "dead"
var mode := "cut"
var play_time := 0.0
var solid_things: Array[Glyph] = []

var _interacts: Array = []
var _goal: Glyph = null
var _shake := 0.0
var _charge := -1.0
var _charge_ticks := 0
## 話しかけたり開けたりした押し下げを、そのまま弓や道具に使わない。
var _need_release := false
var _swing_cd := 0.0
var _leaving := false
var _clear_ready := false
var _lights: Array = []
var _t := 0.0

# ---------------------------------------------------------------- 継承して書くところ

## ステージの番号。
func number() -> int:
	return 0

## 最初に出す一言。
func subtitle() -> String:
	return ""

func bgm_name() -> String:
	return "field"

## 地図を並べ、ものを置く。
func _build() -> void:
	pass

## 毎コマ（遊んでいる間だけ）。
func _stage_process(_delta: float) -> void:
	pass

## 字を使ったとき。自分で扱ったら true。
func on_use(_k: String) -> bool:
	return false

## 斧を振って何かに当てたとき。自分で扱ったら true。
func on_chop(_target: Glyph) -> bool:
	return false

## 矢が何かに当たったとき。当たって消えるなら true。
func on_shot_hit(shot: Shot, target: Glyph) -> bool:
	if target.has_method("hit"):
		target.hit(shot.damage, shot.global_position)
		return true
	return false

func on_shot_wall(_shot: Shot) -> void:
	pass

func on_shot_spent(_shot: Shot) -> void:
	pass

func on_crafted(_k: String) -> void:
	pass

func on_pick(_k: String) -> void:
	pass

# ---------------------------------------------------------------- 組み立て

func _ready() -> void:
	Engine.time_scale = 1.0
	floor_layer = Node2D.new()
	floor_layer.z_index = -10
	add_child(floor_layer)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	hero = Hero.new()
	hero.stage = self
	hud = Hud.new()
	hud.stage = self
	add_child(hud)
	hud.pause_choice.connect(_on_pause_choice)
	if TouchPad.needed():
		add_child(TouchPad.new())
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	add_child(cam)
	_build()
	if hero.get_parent() == null:
		world.add_child(hero)
	_setup_camera()
	var info := Game.stage_info(number())
	hud.set_title("%s「%s」" % [info.get("name", ""), info.get("kanji", "")])
	_refresh_hud()
	Sfx.bgm(bgm_name())
	_intro()

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _setup_camera() -> void:
	var w := cols * CELL
	var h := rows * CELL
	cam.limit_left = mini(0, (w - 640) / 2)
	cam.limit_top = mini(0, (h - 360) / 2)
	cam.limit_right = maxi(w, (w + 640) / 2)
	cam.limit_bottom = maxi(h, (h + 360) / 2)
	cam.global_position = _cam_target()
	cam.reset_smoothing()

func _cam_target() -> Vector2:
	var w := cols * CELL
	var h := rows * CELL
	var p := hero.global_position
	if w <= 640:
		p.x = w * 0.5
	if h <= 360:
		p.y = h * 0.5
	return p

## ステージの題を大きく出す。
func _intro() -> void:
	var info := Game.stage_info(number())
	var box := Node2D.new()
	box.position = Vector2(320, 150)
	hud.add_child(box)
	var big := Glyph.make(info.get("kanji", ""), INK, 96)
	big.outline = 8
	big.outline_color = Color("#f6f0e2")
	box.add_child(big)
	var name := Glyph.make(info.get("name", ""), Hud.RED, 16)
	name.outline = 4
	name.outline_color = Color("#f6f0e2")
	name.position = Vector2(0, -74)
	box.add_child(name)
	var sub := Glyph.make(subtitle(), INK, 15)
	sub.outline = 5
	sub.outline_color = Color("#f6f0e2")
	sub.position = Vector2(0, 72)
	box.add_child(sub)
	box.modulate.a = 0.0
	box.scale = Vector2(1.3, 1.3)
	var tw := box.create_tween()
	tw.set_parallel(true)
	tw.tween_property(box, "modulate:a", 1.0, 0.3)
	tw.tween_property(box, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.1)
	tw.chain().tween_property(box, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(box.queue_free)
	if not await wait(0.7):
		return
	if mode == "cut":
		mode = "play"

# ---------------------------------------------------------------- 地図

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL + CELL * 0.5, c.y * CELL + CELL * 0.5)

func in_map(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows

func solid_at(c: Vector2i) -> int:
	if not in_map(c):
		return WALL
	return _solid[c.y * cols + c.x]

func set_solid(c: Vector2i, kind: int) -> void:
	if in_map(c):
		_solid[c.y * cols + c.x] = kind

## 漢字で書いた地図を読む。legend に無い字は、決まった地形として並べる。
## legend の値は Callable(cell: Vector2i)。
func build_map(map: Array, legend := {}) -> void:
	rows = map.size()
	cols = 0
	for r in map:
		cols = maxi(cols, r.length())
	for i in rows:
		if map[i].length() != cols:
			push_error("地図の %d 行目の長さが %d（ほかは %d）" % [i, map[i].length(), cols])
	_solid.resize(rows * cols)
	_solid.fill(FREE)
	for y in rows:
		var row: String = map[y]
		for x in row.length():
			var ch := row.substr(x, 1)
			var c := Vector2i(x, y)
			if legend.has(ch):
				legend[ch].call(c)
			else:
				_default_tile(ch, c)

func _default_tile(ch: String, c: Vector2i) -> void:
	match ch:
		"・", "　", " ", ".":
			pass
		"山":
			tile(c, "山", COL_MOUNTAIN, WALL)
		"岩":
			tile(c, "岩", COL_ROCK, WALL)
		"壁":
			tile(c, "壁", COL_WALL, WALL)
		"川":
			var g := tile(c, "川", COL_WATER, WATER)
			g.add_to_group("water")
			g.shadow = false
		"木":
			tile(c, "木", COL_TREE, WALL)
		"草":
			decor(c, "草", COL_GRASS)
		"花":
			decor(c, "花", COL_FLOWER)
		"勇":
			hero.position = cell_center(c)
		"標":
			add_goal(cell_center(c))
		_:
			push_warning("地図に知らない字: " + ch)
			decor(c, ch, INK)

## 地形を 1 つ置く。
func tile(c: Vector2i, t: String, col: Color, kind: int) -> Glyph:
	## 筆で書いたように、1 つずつ少しだけ傾きと濃さを変える。
	var g := Glyph.make(t, col.darkened(randf_range(-0.06, 0.08)), 22)
	g.tilt = randf_range(-0.06, 0.06)
	g.position = cell_center(c)
	g.hit_size = Vector2(CELL, CELL)
	world.add_child(g)
	tiles[c] = g
	set_solid(c, kind)
	return g

## 飾り（通れる）。床に敷く。
func decor(c: Vector2i, t: String, col: Color) -> Glyph:
	var g := Glyph.make(t, col, 18)
	g.position = cell_center(c) + Vector2(randf_range(-2, 2), randf_range(-2, 2))
	g.shadow = false
	floor_layer.add_child(g)
	return g

## 地形を取り除く。
func clear_tile(c: Vector2i) -> void:
	if tiles.has(c):
		var g: Glyph = tiles[c]
		if is_instance_valid(g):
			g.queue_free()
		tiles.erase(c)
	set_solid(c, FREE)

## その四角が、地形か固いものに当たっているか。
## fly なら川や淵の上は通れる（飛ぶもの用）。
func blocked(r: Rect2, ignore: Node = null, fly := false) -> bool:
	var c0 := cell_of(r.position)
	var c1 := cell_of(r.end - Vector2(0.01, 0.01))
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			var k := solid_at(Vector2i(x, y))
			if k != FREE and not (fly and k == WATER):
				return true
	for s in solid_things:
		if s != ignore and is_instance_valid(s) and s.is_visible_in_tree() and r.intersects(s.rect()):
			return true
	return false

## 矢がそこで止まるか（川は越える）。
func shot_blocked(p: Vector2) -> bool:
	var k := solid_at(cell_of(p))
	return k == WALL or k == PLANT

# ---------------------------------------------------------------- 置くもの

## 近くで Z を押すと何かが起きるもの。
func add_interact(g: Glyph, label: String, fn: Callable, cond := Callable()) -> void:
	_interacts.append({"g": g, "label": label, "fn": fn, "cond": cond})

func remove_interact(g: Glyph) -> void:
	for i in range(_interacts.size() - 1, -1, -1):
		if _interacts[i]["g"] == g:
			_interacts.remove_at(i)

func set_interact_label(g: Glyph, label: String) -> void:
	for it in _interacts:
		if it["g"] == g:
			it["label"] = label

## 足元に落ちている字。Z で拾える。
func drop_item(k: String, pos: Vector2) -> Glyph:
	var g := Glyph.make(k, hero._hand_color(k), 18)
	g.outline = 4
	g.position = pos
	g.add_to_group("item")
	world.add_child(g)
	## ふわふわ浮かせて、拾えるものだと分かるようにする。
	var tw := g.create_tween().set_loops()
	tw.tween_property(g, "squash", Vector2(1.06, 0.94), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(g, "squash", Vector2(0.96, 1.04), 0.5).set_trans(Tween.TRANS_SINE)
	add_interact(g, "拾う「%s」" % k, func(): pick_item(g))
	return g

func pick_item(g: Glyph) -> void:
	if not is_instance_valid(g):
		return
	var k := g.text
	remove_interact(g)
	var from := g.global_position
	g.queue_free()
	give(k, from)

## 字を手に持たせる。両手がふさがっていたら、古い方を足元に置く。
func give(k: String, from := Vector2.INF) -> void:
	var dropped := hero.give(k)
	if dropped != "":
		drop_item(dropped, _free_spot_near(hero.position))
		hud.toast("「%s」を置いて、「%s」を持った" % [dropped, k])
	else:
		var note: String = Kanji.PART_NOTE.get(k, "")
		hud.toast("「%s」を手にした　%s" % [k, note] if note != "" else "「%s」を手にした" % k)
	Sfx.play("pick")
	if from != Vector2.INF:
		var hg := hero.hand_glyph(k)
		if hg != null:
			## 拾ったところから手元へ飛んでくる。
			var start := from - hero.global_position
			var end := hg.position
			hg.position = start
			var tw := hg.create_tween()
			tw.tween_property(hg, "position", end, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func(): Fx.pop(hg, 0.5))
	_refresh_hud()
	on_pick(k)

## 手から字を消す。
func consume(k: String) -> void:
	hero.take(k)
	_refresh_hud()

## p のそばで、足元に物を置ける所。
func _free_spot_near(p: Vector2) -> Vector2:
	for d in [Vector2(0, 16), Vector2(-18, 8), Vector2(18, 8), Vector2(0, -16), Vector2(-20, -10), Vector2(20, -10)]:
		var q: Vector2 = p + d
		if solid_at(cell_of(q)) == FREE:
			return q
	return p

## 命のかけら。触れると命が 1 つ戻る。
func drop_heart(pos: Vector2) -> void:
	var g := Glyph.make("命", Hud.RED, 14)
	g.outline = 3
	g.position = pos
	g.add_to_group("heart")
	world.add_child(g)
	var tw := g.create_tween().set_loops()
	tw.tween_property(g, "position:y", pos.y - 4.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(g, "position:y", pos.y, 0.4).set_trans(Tween.TRANS_SINE)

func _pick_hearts() -> void:
	for g in get_tree().get_nodes_in_group("heart"):
		if hero.touching(g) and hero.hp < hero.max_hp:
			hero.hp += 1
			Sfx.play("heal")
			Fx.float_text(world, g.position + Vector2(0, -12), "＋命", Hud.RED, 12)
			g.queue_free()
			_refresh_hud()

## 宝箱。content は字か、字を返す Callable。refill なら何度でも開く。
func add_chest(c: Vector2i, content, refill := false) -> Glyph:
	var g := tile(c, "宝箱", COL_CHEST, WALL)
	g.size = 14
	g.hit_size = Vector2(CELL, CELL)
	g.set_meta("opened", false)
	add_interact(g, "開ける「宝箱」", func(): _open_chest(g, content, refill),
		func(): return refill or not g.get_meta("opened"))
	return g

func _open_chest(g: Glyph, content, refill: bool) -> void:
	var k: String = content.call() if content is Callable else content
	Sfx.play("open")
	Fx.pop(g, 0.4)
	if k == "":
		hud.toast("空っぽだ")
		return
	if not refill:
		g.set_meta("opened", true)
		g.text = "空箱"
		g.color = COL_EMPTY
	Fx.burst(world, g.position + Vector2(0, -8), Color("#e8c547"), 8, "・＊", 90.0, 10)
	give(k, g.global_position + Vector2(0, -10))

## 話しかけられる人。on_talk は会話 [["名前", "せりふ"], ...] か、
## 話しかけたときにすること（その人の Glyph を受け取る Callable）。
func add_npc(pos: Vector2, t: String, col: Color, on_talk, solid := true) -> Glyph:
	var g := Glyph.make(t, col, 20)
	g.position = pos
	g.hit_size = Vector2(18 * t.length(), 18)
	g.add_to_group("npc")
	world.add_child(g)
	if solid:
		solid_things.append(g)
	if on_talk is Callable:
		add_interact(g, "話す「%s」" % t, func(): on_talk.call(g))
	else:
		add_interact(g, "話す「%s」" % t, func(): talk(on_talk))
	return g

## 立て札。
func add_sign(c: Vector2i, lines: Array) -> Glyph:
	var g := tile(c, "札", COL_SIGN, WALL)
	add_interact(g, "読む「札」", func(): talk(lines))
	return g

## 目標。触れるとクリア。
func add_goal(pos: Vector2, t := "目標") -> Glyph:
	_goal = Glyph.make(t, INK, 18)
	_goal.position = pos
	_goal.outline = 4
	_goal.outline_color = Color("#f6f0e2")
	world.add_child(_goal)
	var tw := _goal.create_tween().set_loops()
	tw.tween_property(_goal, "squash", Vector2(1.08, 0.92), 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_goal, "squash", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	return _goal

func goal() -> Glyph:
	return _goal

# ---------------------------------------------------------------- 毎コマ

func frozen() -> bool:
	return mode != "play"

func _process(delta: float) -> void:
	_t += delta
	_update_camera(delta)
	_update_lights()
	if mode == "clear":
		if _clear_ready and (Input.is_action_just_pressed("act") or Input.is_action_just_pressed("ui_accept")):
			_clear_ready = false
			Sfx.play("confirm")
			_leaving = true
			Game.goto_next_stage()
		return
	if mode != "play":
		hero.can_move = false
		hud.set_prompt("")
		return
	hero.can_move = true
	play_time += delta
	if Input.is_action_just_pressed("pause"):
		_open_pause()
		return
	_swing_cd = maxf(0.0, _swing_cd - delta)
	if not Input.is_action_pressed("act"):
		_need_release = false
	var near := _nearest_interact()
	_update_prompt(near)
	if _charge >= 0.0:
		_process_charge(delta)
	elif Input.is_action_just_pressed("act"):
		if not near.is_empty():
			_need_release = true
			near["fn"].call()
		elif not _need_release:
			_use_tools()
	if mode == "play" and Input.is_action_just_pressed("craft"):
		_try_craft()
	_animate_water()
	_pick_hearts()
	if mode == "play":
		_stage_process(delta)
	if mode == "play" and _goal != null and is_instance_valid(_goal) and _goal.visible and hero.touching(_goal):
		clear()

func _nearest_interact() -> Dictionary:
	var best := {}
	var best_d := INF
	var hr := hero.rect().grow(REACH)
	for it in _interacts:
		var g: Glyph = it["g"]
		if not is_instance_valid(g) or not g.is_visible_in_tree():
			continue
		var cond: Callable = it["cond"]
		if cond.is_valid() and not cond.call():
			continue
		if not hr.intersects(g.rect()):
			continue
		## 向いている方にあるものを先にする。背中側のものは後回し。
		var to := g.global_position - hero.global_position
		var d := to.length() - 14.0 * hero.facing.dot(to.normalized())
		if d < best_d:
			best_d = d
			best = it
	return best

func _update_prompt(near: Dictionary) -> void:
	var a := TouchPad.act_name()
	var t := ""
	if not near.is_empty():
		t = "%s %s" % [a, near["label"]]
	elif _charge >= 0.0:
		t = "離して放つ"
	else:
		var k := _usable_tool()
		if k == "弓":
			t = "%s 長押しで引き絞る" % a
		elif k != "":
			t = "%s 使う「%s」" % [a, k]
	hud.set_prompt(t)

func _usable_tool() -> String:
	for k in USE_ORDER:
		if hero.holding(k):
			return k
	return ""

func _update_camera(delta: float) -> void:
	cam.global_position = _cam_target()
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 30.0)
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	else:
		cam.offset = Vector2.ZERO

func shake(amount := 6.0) -> void:
	_shake = maxf(_shake, amount)

## 当たった瞬間だけ時を止めて、手応えを出す。
func hitstop(sec := 0.06) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(sec, true, false, true).timeout
	Engine.time_scale = 1.0

func _animate_water() -> void:
	for g in get_tree().get_nodes_in_group("water"):
		var gg: Glyph = g
		gg.tilt = sin(_t * 2.0 + gg.position.x * 0.05 + gg.position.y * 0.03) * 0.12

# ---------------------------------------------------------------- 待つ

## この場面を離れたか。演出は await をまたぐので、続きの前に確かめる。
func left() -> bool:
	return _leaving or not is_inside_tree()

## 待つ。まだこの場面にいれば true。
func wait(sec: float) -> bool:
	if left():
		return false
	await get_tree().create_timer(sec, false).timeout
	return not left()

# ---------------------------------------------------------------- 話す

func talk(lines: Array) -> void:
	if lines.is_empty():
		return
	var prev := mode
	mode = "talk"
	hero.vel = Vector2.ZERO
	hud.set_prompt("")
	get_tree().paused = true
	hud.talk(lines)
	await hud.dialog_done
	if not is_inside_tree():
		return
	get_tree().paused = false
	_need_release = true
	if mode == "talk":
		mode = prev

# ---------------------------------------------------------------- 合わせる

func _try_craft() -> void:
	var n := hero.hands.size()
	if n == 0:
		hud.toast("両手に字を持つと、合わせられる")
		Sfx.play("fail", 1.3)
		return
	if n == 1:
		var k: String = hero.hands[0]
		consume(k)
		drop_item(k, _free_spot_near(hero.position))
		Sfx.play("drop")
		hud.toast("「%s」を置いた（両手に持つと合わせられる）" % k)
		return
	var a: String = hero.hands[0]
	var b: String = hero.hands[1]
	var r := Kanji.combine(a, b)
	if r == "":
		Sfx.play("fail")
		Fx.pop(hero, -0.3)
		hud.toast("「%s」と「%s」は、合わない…" % [a, b])
		return
	await craft_anim(a, b, r)

## 両手の字がぐるりと回って 1 つになる。
func craft_anim(a: String, b: String, r: String) -> void:
	mode = "cut"
	hero.vel = Vector2.ZERO
	hud.set_prompt("")
	var ga := Glyph.make(a, hero._hand_color(a), 16)
	var gb := Glyph.make(b, hero._hand_color(b), 16)
	var center := hero.position + Vector2(0, -34)
	ga.position = hero.position + Vector2(-15, -12)
	gb.position = hero.position + Vector2(15, -12)
	ga.z_index = 40
	gb.z_index = 40
	world.add_child(ga)
	world.add_child(gb)
	hero.set_hands([])
	_refresh_hud()
	Sfx.play("charge", 0.8)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var ang := t * TAU * 1.5
		var rad := lerpf(20.0, 0.0, t)
		ga.position = center + Vector2.from_angle(ang + PI) * rad
		gb.position = center + Vector2.from_angle(ang) * rad
		ga.size = int(lerpf(16, 26, t))
		gb.size = int(lerpf(16, 26, t)), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	if left():
		return
	ga.queue_free()
	gb.queue_free()
	Sfx.play("craft")
	Fx.ring(world, center, Color("#d9a400"), 220.0, 0.4, 4.0)
	Fx.burst(world, center, Color("#d9a400"), 14, "・＊", 160.0, 12)
	var big := Glyph.make(r, hero._hand_color(r), 40)
	big.outline = 5
	big.outline_color = Color("#fff8e0")
	big.position = center
	big.z_index = 40
	world.add_child(big)
	Fx.flash(big, 0.4)
	Fx.pop(big, 0.6, 0.4)
	shake(3.0)
	if not await wait(0.35):
		return
	var tw2 := big.create_tween()
	tw2.tween_property(big, "position", hero.position + Vector2(15, -12), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.parallel().tween_property(big, "size", 13, 0.18)
	await tw2.finished
	big.queue_free()
	if left():
		return
	hero.set_hands([r])
	_refresh_hud()
	var is_new := Game.discover(r)
	get_tree().paused = true
	hud.card(r, is_new)
	await hud.card_done
	if not is_inside_tree():
		return
	get_tree().paused = false
	_need_release = true
	mode = "play"
	on_crafted(r)

# ---------------------------------------------------------------- 使う

func _use_tools() -> void:
	var k := _usable_tool()
	if k == "":
		if hero.hands.size() > 0:
			var last: String = hero.hands[-1]
			hud.toast(Kanji.PART_NOTE.get(last, "「%s」は、ここでは使えない" % last))
		return
	if on_use(k):
		return
	match k:
		"弓":
			_charge = 0.0
			_charge_ticks = 0
			hero.speed_scale = 0.45
		"斧":
			swing_axe()
		"炎":
			consume("炎")
			fire_shot("炎", 1.0, true)
			Sfx.play("fire")
		"休", "星":
			if hero.hp >= hero.max_hp:
				hud.toast("まだ元気だ。命が減ったら使おう")
				return
			consume(k)
			heal_hero(k)
		"林", "森":
			plant(k)
		"鳴":
			Sfx.play("alert", 0.8)
			Fx.float_text(world, hero.position + Vector2(0, -26), "ピィーッ！", Hud.RED, 14)
		_:
			hud.toast(Kanji.INFO.get(k, {}).get("desc", ""))

func heal_hero(k: String) -> void:
	hero.heal_full()
	Sfx.play("heal")
	Fx.burst(world, hero.position, Color("#e05a7a"), 10, "命♡", 90.0, 12)
	Fx.float_text(world, hero.position + Vector2(0, -24), "命が戻った", Hud.RED, 13)
	var old := hero.text
	hero.text = k
	_refresh_hud()
	await wait(0.8)
	if is_instance_valid(hero) and hero.text == k:
		hero.text = old

## 林や森を目の前に植える。森は 3 マスの幅で植わる。
func plant(k: String) -> bool:
	var f := _facing4()
	var front := cell_of(hero.position) + Vector2i(f)
	var cells: Array[Vector2i] = [front]
	if k == "森":
		var side := Vector2i(int(f.y), int(f.x))
		cells = [front - side, front, front + side]
	for c in cells:
		if solid_at(c) != FREE or Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)).intersects(hero.rect()):
			hud.toast("ここには植えられない")
			Sfx.play("fail")
			return false
	consume(k)
	for c in cells:
		var g := tile(c, k, COL_TREE, PLANT)
		g.squash = Vector2(0.2, 0.2)
		var tw := g.create_tween()
		tw.tween_property(g, "squash", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Fx.burst(world, g.position, COL_TREE, 5, "・", 60.0, 10)
	Sfx.play("pop")
	on_planted(k, cells)
	return true

func on_planted(_k: String, _cells: Array[Vector2i]) -> void:
	pass

func _facing4() -> Vector2:
	var f := hero.facing
	if absf(f.x) >= absf(f.y):
		return Vector2(signf(f.x), 0)
	return Vector2(0, signf(f.y))

## 斧を向いている方へ振る。
func swing_axe() -> void:
	if _swing_cd > 0.0:
		return
	_swing_cd = 0.4
	var f := hero.facing
	var axe := Glyph.make("斧", Color("#6b7680"), 18)
	axe.z_index = 30
	hero.add_child(axe)
	Sfx.play("swing")
	var base_ang := f.angle()
	var tw := axe.create_tween()
	tw.tween_method(func(t: float):
		var ang := base_ang + lerpf(-1.3, 1.3, t)
		axe.position = Vector2.from_angle(ang) * 18.0
		axe.tilt = ang + PI / 2.0
		axe.squash = Vector2(1.0 + sin(t * PI) * 0.4, 1.0 - sin(t * PI) * 0.2), 0.0, 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.05)
	tw.tween_callback(axe.queue_free)
	var hit := Rect2(hero.global_position + f * 20.0 - Vector2(14, 14), Vector2(28, 28))
	if not await wait(0.08):
		return
	for g in get_tree().get_nodes_in_group("choppable"):
		if g is Glyph and g.is_visible_in_tree() and hit.intersects(g.rect()):
			if on_chop(g):
				return
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Glyph and e.is_visible_in_tree() and hit.intersects(e.rect()) and e.has_method("hit"):
			e.hit(1, hero.global_position)

# ---------------------------------------------------------------- 弓

func _process_charge(delta: float) -> void:
	if not hero.holding("弓"):
		_end_charge()
		return
	if Input.is_action_pressed("act"):
		_charge = minf(1.0, _charge + delta / CHARGE_TIME)
		var ticks := int(_charge * 3.0)
		if ticks > _charge_ticks:
			_charge_ticks = ticks
			Sfx.play("charge", 1.0 + ticks * 0.25)
			if ticks >= 3:
				Fx.flash(hero, 0.2)
				Fx.ring(world, hero.position, Color("#e0561b"), 80.0, 0.25, 2.0)
		hero.color = Color("#1a1a1a").lerp(Color("#d0402a"), _charge)
		var k := _charge * 0.18
		hero.squash = Vector2(1.0 + k, 1.0 - k * 0.5)
		return
	var p := _charge
	_end_charge()
	fire_arrow(p)

func _end_charge() -> void:
	_charge = -1.0
	hero.speed_scale = 1.0
	hero.color = Color("#1a1a1a")

## 手に火があれば火矢になる。
func has_fire() -> bool:
	return hero.holding("火") or hero.holding("灯") or hero.holding("炎")

func fire_arrow(power: float) -> Shot:
	var fire := has_fire()
	var s := fire_shot("矢", power, fire)
	Sfx.play("shoot", 0.8 + power * 0.4)
	return s

func fire_shot(t: String, power: float, fire: bool) -> Shot:
	var s := Shot.new()
	s.stage = self
	s.text = t
	s.size = 16 if t == "矢" else 20
	s.color = COL_FIRE if fire else COL_ARROW
	s.dir = hero.facing
	s.orient = t == "矢"
	s.power = power
	s.fire = fire
	s.speed = 200.0 + 320.0 * power
	## 引きが浅いとほとんど飛ばない。しっかりためて、ようやく遠くまで届く。
	s.reach = 30.0 + 400.0 * power * power
	if t == "炎":
		s.reach = 320.0
		s.speed = 260.0
		s.damage = 3
	s.position = hero.position + hero.facing * 14.0
	world.add_child(s)
	return s

# ---------------------------------------------------------------- 命

func hurt_hero(n: int, from: Vector2) -> bool:
	if mode != "play":
		return false
	if not hero.damage(n, from):
		return false
	Sfx.play("hurt")
	shake(7.0)
	hitstop(0.07)
	_end_charge()
	_refresh_hud()
	Fx.burst(world, hero.position, Hud.RED, 8, "・", 120.0, 11)
	if hero.hp <= 0:
		die()
	return true

func die() -> void:
	mode = "dead"
	Game.deaths += 1
	Game.save()
	Sfx.bgm("")
	Sfx.play("death")
	hero.text = "倒"
	hero.color = Color("#6b6259")
	var tw := hero.create_tween()
	tw.tween_property(hero, "tilt", PI / 2.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	hud.toast("倒れた…　もう一度", Hud.RED, 2.0)
	if not await wait(1.8):
		return
	restart()

func restart() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().paused = false
	Game.change_scene(scene_file_path)

# ---------------------------------------------------------------- クリア

func clear() -> void:
	if mode == "clear":
		return
	mode = "clear"
	hero.vel = Vector2.ZERO
	_end_charge()
	Sfx.bgm("")
	Sfx.play("clear")
	hitstop(0.12)
	Fx.ring(world, _goal.position, Color("#d9a400"), 260.0, 0.6, 5.0)
	Fx.burst(world, _goal.position, Color("#d9a400"), 20, "・＊", 200.0, 12)
	var best := Game.mark_cleared(number(), play_time)
	if not await wait(0.5):
		return
	await stamp("達成")
	if left():
		return
	var tt := Glyph.make("かかった時間　%s%s" % [fmt_time(play_time), "　最速！" if best else ""], INK, 14)
	tt.outline = 5
	tt.outline_color = Color("#f6f0e2")
	tt.position = Vector2(320, 250)
	hud.add_child(tt)
	if not await wait(0.5):
		return
	var nxt := "%s 次へ" % TouchPad.act_name()
	hud.set_prompt("")
	var hint := Glyph.make(nxt, Hud.RED, 15)
	hint.outline = 5
	hint.outline_color = Color("#f6f0e2")
	hint.position = Vector2(320, 285)
	hud.add_child(hint)
	var tw := hint.create_tween().set_loops()
	tw.tween_property(hint, "modulate:a", 0.3, 0.5)
	tw.tween_property(hint, "modulate:a", 1.0, 0.5)
	_clear_ready = true

static func fmt_time(sec: float) -> String:
	var m := int(sec) / 60
	var s := int(sec) % 60
	return "%d分%02d秒" % [m, s]

## 朱の判子を、どんと押す。
func stamp(t: String) -> void:
	var st := _Stamp.new()
	st.text = t
	st.position = Vector2(320, 160)
	st.rotation = -0.18
	st.scale = Vector2(3.0, 3.0)
	st.modulate.a = 0.0
	hud.add_child(st)
	var tw := st.create_tween()
	tw.set_parallel(true)
	tw.tween_property(st, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(st, "modulate:a", 1.0, 0.1)
	await tw.finished
	Sfx.play("stamp")
	shake(8.0)
	Fx.ring(hud, st.position, Hud.RED, 300.0, 0.4, 4.0)

class _Stamp extends Node2D:
	var text := ""
	func _draw() -> void:
		var red := Color("#c0392b")
		var r := Rect2(-70, -42, 140, 84)
		draw_rect(r, Color(red, 0.08))
		draw_rect(r, red, false, 5.0)
		draw_rect(r.grow(-7), Color(red, 0.6), false, 1.5)
		var f := Glyph.bold_font()
		var fs := 48
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(-w * 0.5, fs * 0.38), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, red)

# ---------------------------------------------------------------- 一時停止

func _open_pause() -> void:
	get_tree().paused = true
	Sfx.play("select")
	hud.open_pause()

func _on_pause_choice(choice: String) -> void:
	get_tree().paused = false
	match choice:
		"retry":
			restart()
		"title":
			_leaving = true
			Game.goto_title()

# ---------------------------------------------------------------- 表示

func _refresh_hud() -> void:
	hud.set_hp(hero.hp, hero.max_hp)
	var r := ""
	if hero.hands.size() == 2:
		r = Kanji.combine(hero.hands[0], hero.hands[1])
	hud.set_hands(hero.hands, r, Game.discovered.has(r))

# ---------------------------------------------------------------- 明かり

## 暗がりにする。明かりの無い所は見えない。
func enable_dark(ambient := 0.0) -> void:
	dark = Dark.new()
	dark.ambient = ambient
	add_child(dark)

var _glow: Node2D = null

## 闇より手前に描く層。暗がりでも見えていてほしいもの（敵の弾など）を置く。
## 地図と同じ座標で置ける（カメラについていく）。
func glow_layer() -> Node2D:
	if _glow == null:
		var cl := CanvasLayer.new()
		cl.layer = 11
		cl.follow_viewport_enabled = true
		add_child(cl)
		_glow = Node2D.new()
		cl.add_child(_glow)
	return _glow

## node の場所に明かりを置く（node が動けば明かりもついてくる）。
func add_light(node: Node2D, radius: float, strength := 1.0) -> void:
	_lights.append({"node": node, "r": radius, "s": strength})

func remove_light(node: Node2D) -> void:
	for i in range(_lights.size() - 1, -1, -1):
		if _lights[i]["node"] == node:
			_lights.remove_at(i)

func set_light_radius(node: Node2D, radius: float) -> void:
	for l in _lights:
		if l["node"] == node:
			l["r"] = radius

## その場所の明るさ（0〜1）。シェーダーと同じ式。
func light_at(p: Vector2) -> float:
	var lit := dark.ambient if dark != null else 1.0
	for l in _lights:
		var n: Node2D = l["node"]
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var d := p.distance_to(n.global_position)
		var r: float = l["r"]
		var k := 1.0 - smoothstep(r * 0.35, r, d)
		lit = maxf(lit, k * float(l["s"]))
	return lit

func _update_lights() -> void:
	if dark == null:
		return
	var ct := get_viewport().get_canvas_transform()
	var list := []
	for i in range(_lights.size() - 1, -1, -1):
		var n: Node2D = _lights[i]["node"]
		if not is_instance_valid(n) or not n.is_inside_tree():
			_lights.remove_at(i)
	for l in _lights:
		var n: Node2D = l["node"]
		list.append([ct * n.global_position, l["r"], l["s"]])
	dark.update_lights(list, _t)
