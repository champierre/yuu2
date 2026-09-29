class_name Hud
extends CanvasLayer
## 画面に重ねて出すもの。命・両手・案内・会話・合わせた字の札・一時停止。
##
## ゲームを止めている間（会話や札）も動くよう、常に動かす。

signal dialog_done
signal card_done
signal pause_choice(choice: String)

const INK := Color("#1f1a16")
const PAPER := Color("#f6f0e2")
const RED := Color("#b8322a")
const SUB := Color("#6b6259")

var stage: Node = null

var _hearts: Array[Glyph] = []
var _title: Glyph
var _hand_boxes: Array[Node2D] = []
var _hand_glyphs: Array[Glyph] = []
var _craft_hint: Glyph
var _prompt: Glyph
var _toast: Glyph
var _toast_tw: Tween
var _boss_bar: _Bar

var _dialog: Node2D
var _dialog_name: Glyph
var _dialog_label: Label
var _dialog_arrow: Glyph
var _lines: Array = []
var _line_i := 0
var _typing := 0.0
var _talking := false
var _talk_armed := false

var _card: Node2D
var _card_showing := false
var _card_armed := false
var _card_time := 0.0

var _pause: Node2D
var _pause_items: Array[Glyph] = []
var _pause_i := 0
var _pausing := false
var _pause_skip := false

var _t := 0.0

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_top()
	_build_dialog()
	_build_card()
	_build_pause()

# ---------------------------------------------------------------- 上の段

func _build_top() -> void:
	for i in 5:
		var h := Glyph.make("命", RED, 16)
		h.outline = 4
		h.outline_color = PAPER
		h.position = Vector2(18 + i * 20, 16)
		h.visible = false
		add_child(h)
		_hearts.append(h)
	_title = Glyph.make("", SUB, 13)
	_title.outline = 4
	_title.outline_color = PAPER
	_title.shadow = false
	_title.position = Vector2(320, 14)
	add_child(_title)
	for i in 2:
		var box := _Box.new()
		box.position = Vector2(572 + i * 34, 22)
		add_child(box)
		_hand_boxes.append(box)
		var g := Glyph.make("", INK, 20)
		g.position = box.position
		add_child(g)
		_hand_glyphs.append(g)
	var lbl := Glyph.make("手", SUB, 10)
	lbl.shadow = false
	lbl.position = Vector2(549, 22)
	add_child(lbl)
	_craft_hint = Glyph.make("", RED, 12)
	_craft_hint.outline = 4
	_craft_hint.outline_color = PAPER
	_craft_hint.position = Vector2(589, 50)
	add_child(_craft_hint)
	_prompt = Glyph.make("", INK, 13)
	_prompt.bold = false
	_prompt.outline = 5
	_prompt.outline_color = PAPER
	_prompt.position = Vector2(320, 342)
	add_child(_prompt)
	_toast = Glyph.make("", INK, 14)
	_toast.outline = 5
	_toast.outline_color = PAPER
	_toast.position = Vector2(320, 64)
	_toast.modulate.a = 0.0
	add_child(_toast)
	_boss_bar = _Bar.new()
	_boss_bar.position = Vector2(220, 34)
	_boss_bar.visible = false
	add_child(_boss_bar)

class _Box extends Node2D:
	var glow := 0.0:
		set(v):
			glow = v
			queue_redraw()
	func _draw() -> void:
		var r := Rect2(-14, -14, 28, 28)
		draw_rect(r, Color(1, 1, 1, 0.55))
		draw_rect(r, Color(0.12, 0.1, 0.09, 0.7), false, 1.5)
		if glow > 0.0:
			draw_rect(r.grow(2), Color(0.72, 0.2, 0.16, glow), false, 2.0)

class _Bar extends Node2D:
	var ratio := 1.0:
		set(v):
			ratio = v
			queue_redraw()
	var label := ""
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 200, 6), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(0, 0, 200 * ratio, 6), Color("#7a1f3d"))
		draw_rect(Rect2(0, 0, 200, 6), Color(0, 0, 0, 0.6), false, 1.0)

var _debug_badge: Glyph = null

## デバッグモードの印。遊んでいる人に紛らわしくないよう、隅に小さく出す。
func show_debug_badge(t: String) -> void:
	if _debug_badge == null:
		_debug_badge = Glyph.make("", RED, 10)
		_debug_badge.bold = false
		_debug_badge.shadow = false
		_debug_badge.outline = 3
		_debug_badge.outline_color = PAPER
		add_child(_debug_badge)
	_debug_badge.text = t
	_debug_badge.position = Vector2(12 + _debug_badge.box().x * 0.5, 40)

func has_debug_badge() -> bool:
	return _debug_badge != null and _debug_badge.text != ""

func set_title(t: String) -> void:
	_title.text = t

func set_hp(hp: int, max_hp: int) -> void:
	for i in _hearts.size():
		var h := _hearts[i]
		h.visible = i < max_hp
		var was := h.color
		h.color = RED if i < hp else Color(0.5, 0.45, 0.4, 0.35)
		if was != h.color and i >= hp:
			Fx.shake(h, 3.0, 0.3)

func set_hands(hands: Array, combinable: String, known: bool) -> void:
	for i in 2:
		var g := _hand_glyphs[i]
		var t: String = hands[i] if i < hands.size() else ""
		if g.text != t and t != "":
			Fx.pop(g, 0.5)
		g.text = t
	if combinable != "":
		_craft_hint.text = "%s 合わせる → %s" % [TouchPad.craft_name(), combinable if known else "？"]
		_craft_hint.position.x = 640 - 10 - _craft_hint.box().x * 0.5
	else:
		_craft_hint.text = ""

func set_prompt(t: String) -> void:
	_prompt.text = t

func toast(t: String, col := INK, dur := 1.6) -> void:
	_toast.text = t
	_toast.color = col
	_toast.modulate.a = 1.0
	Fx.pop(_toast, 0.3)
	if _toast_tw != null and _toast_tw.is_valid():
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(dur)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.4)

func boss_bar(ratio: float, show := true) -> void:
	_boss_bar.visible = show
	_boss_bar.ratio = clampf(ratio, 0.0, 1.0)

func _process(delta: float) -> void:
	_t += delta
	var glow := 0.0
	if _craft_hint.text != "":
		glow = 0.5 + 0.5 * sin(_t * 6.0)
		_craft_hint.modulate.a = 0.6 + 0.4 * sin(_t * 6.0)
	for b in _hand_boxes:
		b.glow = glow
	_process_dialog(delta)
	_process_card(delta)
	_process_pause()

# ---------------------------------------------------------------- 会話

func _build_dialog() -> void:
	_dialog = Node2D.new()
	_dialog.visible = false
	add_child(_dialog)
	var bg := _Panel.new()
	bg.rect = Rect2(40, 262, 560, 84)
	_dialog.add_child(bg)
	_dialog_name = Glyph.make("", RED, 15)
	_dialog_name.outline = 4
	_dialog_name.outline_color = PAPER
	_dialog_name.position = Vector2(80, 262)
	_dialog.add_child(_dialog_name)
	_dialog_label = Label.new()
	_dialog_label.position = Vector2(60, 276)
	_dialog_label.size = Vector2(520, 60)
	_dialog_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_dialog_label.add_theme_color_override("font_color", INK)
	_dialog_label.add_theme_font_size_override("font_size", 15)
	_dialog_label.add_theme_constant_override("line_spacing", 2)
	_dialog.add_child(_dialog_label)
	_dialog_arrow = Glyph.make("▼", RED, 10)
	_dialog_arrow.shadow = false
	_dialog_arrow.position = Vector2(584, 334)
	_dialog.add_child(_dialog_arrow)

class _Panel extends Node2D:
	var rect := Rect2()
	func _draw() -> void:
		draw_rect(rect, Color(0.975, 0.955, 0.91, 0.96))
		draw_rect(rect, Color(0.12, 0.1, 0.09, 0.85), false, 2.0)
		draw_rect(rect.grow(-4), Color(0.12, 0.1, 0.09, 0.25), false, 1.0)

## 会話を出す。lines は [["話す人", "言うこと"], ...]。
func talk(lines: Array) -> void:
	_lines = lines
	_line_i = 0
	_talking = true
	_talk_armed = false
	_dialog.visible = true
	_show_line()

func is_talking() -> bool:
	return _talking

func _show_line() -> void:
	var l: Array = _lines[_line_i]
	_dialog_name.text = l[0]
	_dialog_name.position.x = 60 + _dialog_name.box().x * 0.5
	_dialog_label.text = l[1]
	_dialog_label.visible_characters = 0
	_typing = 0.0

func _process_dialog(delta: float) -> void:
	if not _talking:
		return
	var total := _dialog_label.text.length()
	if _dialog_label.visible_characters < total:
		_typing += delta * 45.0
		var n := mini(total, int(_typing))
		if n != _dialog_label.visible_characters:
			_dialog_label.visible_characters = n
			if n % 2 == 0:
				Sfx.play("blip", randf_range(0.95, 1.05))
	_dialog_arrow.visible = _dialog_label.visible_characters >= total and int(_t * 3.0) % 2 == 0
	## 話しかけたときの押し下げを拾わないよう、いったん離すのを待つ。
	if not Input.is_action_pressed("act"):
		_talk_armed = true
	if _talk_armed and Input.is_action_just_pressed("act"):
		if _dialog_label.visible_characters < total:
			_dialog_label.visible_characters = total
			_typing = total
		else:
			_line_i += 1
			if _line_i >= _lines.size():
				_talking = false
				_dialog.visible = false
				dialog_done.emit()
			else:
				Sfx.play("select", 0.8)
				_show_line()

# ---------------------------------------------------------------- 合わせた字の札

func _build_card() -> void:
	_card = Node2D.new()
	_card.visible = false
	_card.position = Vector2(320, 170)
	add_child(_card)

## 合わせてできた字を大きく見せる。
func card(result: String, is_new: bool) -> void:
	for c in _card.get_children():
		c.queue_free()
	var bg := _Panel.new()
	bg.rect = Rect2(-150, -110, 300, 210)
	_card.add_child(bg)
	var big := Glyph.make(result, INK, 76)
	big.position = Vector2(0, -30)
	big.outline = 6
	big.outline_color = PAPER
	_card.add_child(big)
	var info: Dictionary = Kanji.INFO.get(result, {})
	var f := Glyph.make(Kanji.formula(result) + " ＝ " + result, SUB, 15)
	f.shadow = false
	f.position = Vector2(0, 32)
	_card.add_child(f)
	var yomi := Glyph.make("「%s」" % info.get("yomi", ""), RED, 13)
	yomi.shadow = false
	yomi.position = Vector2(0, 54)
	_card.add_child(yomi)
	var d := Label.new()
	d.text = info.get("desc", "")
	d.position = Vector2(-135, 64)
	d.size = Vector2(270, 36)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	d.add_theme_color_override("font_color", INK)
	d.add_theme_font_size_override("font_size", 12)
	_card.add_child(d)
	if is_new:
		var n := Glyph.make("新発見！ 字典に載った", RED, 12)
		n.outline = 4
		n.outline_color = PAPER
		n.position = Vector2(0, -98)
		_card.add_child(n)
	_card.visible = true
	_card.scale = Vector2(0.3, 0.3)
	_card.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.2)
	_card_showing = true
	_card_armed = false
	_card_time = 0.0

func _process_card(delta: float) -> void:
	if not _card_showing:
		return
	_card_time += delta
	if not Input.is_action_pressed("act") and not Input.is_action_pressed("craft"):
		_card_armed = true
	var go := _card_armed and _card_time > 0.5 and (Input.is_action_just_pressed("act") or Input.is_action_just_pressed("craft"))
	if go or _card_time > 3.5:
		_card_showing = false
		var tw := create_tween()
		tw.tween_property(_card, "modulate:a", 0.0, 0.15)
		tw.tween_callback(func(): _card.visible = false)
		card_done.emit()

# ---------------------------------------------------------------- 一時停止

func _build_pause() -> void:
	_pause = Node2D.new()
	_pause.visible = false
	add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.06, 0.45)
	dim.size = Vector2(640, 360)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause.add_child(dim)
	var bg := _Panel.new()
	bg.rect = Rect2(220, 90, 200, 180)
	_pause.add_child(bg)
	var t := Glyph.make("一時停止", INK, 20)
	t.position = Vector2(320, 118)
	_pause.add_child(t)
	var labels := ["つづける", "やりなおす", "タイトルへ"]
	for i in labels.size():
		var g := Glyph.make(labels[i], INK, 16)
		g.bold = false
		g.shadow = false
		g.position = Vector2(320, 164 + i * 32)
		_pause.add_child(g)
		_pause_items.append(g)

func open_pause() -> void:
	## 開いたコマの「止」の押し下げで、すぐ閉じないようにする。
	_pause_skip = true
	_pausing = true
	_pause_i = 0
	_pause.visible = true
	_refresh_pause()

func is_pausing() -> bool:
	return _pausing

func _refresh_pause() -> void:
	for i in _pause_items.size():
		var g := _pause_items[i]
		g.color = RED if i == _pause_i else SUB
		g.text = ("▶ " if i == _pause_i else "") + ["つづける", "やりなおす", "タイトルへ"][i]

func _process_pause() -> void:
	if not _pausing:
		return
	if _pause_skip:
		_pause_skip = false
		return
	if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("down"):
		_pause_i = (_pause_i + 1) % 3
		Sfx.play("select")
		_refresh_pause()
	elif Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("up"):
		_pause_i = (_pause_i + 2) % 3
		Sfx.play("select")
		_refresh_pause()
	elif Input.is_action_just_pressed("act") or Input.is_action_just_pressed("ui_accept"):
		_close_pause(["resume", "retry", "title"][_pause_i])
	elif Input.is_action_just_pressed("pause"):
		_close_pause("resume")

func _close_pause(choice: String) -> void:
	_pausing = false
	_pause.visible = false
	Sfx.play("confirm")
	pause_choice.emit(choice)
