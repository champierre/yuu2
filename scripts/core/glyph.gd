class_name Glyph
extends Node2D
## 字 1 つ（または数文字）を絵として描く。登場するものはすべてこれ。
##
## 当たり判定 rect() は hit_size から作り、回転・拡大・squash を見ない。
## だから見た目はいくら傾けたり伸ばしたりしてもよく、判定はぶれない。

static var _font: Font
static var _bold: FontVariation

var text := "":
	set(v):
		text = v
		_measure()
		queue_redraw()
var color := Color.BLACK:
	set(v):
		color = v
		queue_redraw()
var size := 22:
	set(v):
		size = v
		_measure()
		queue_redraw()
## true で字を縦に積む。
var vertical := false:
	set(v):
		vertical = v
		_measure()
		queue_redraw()
var bold := true:
	set(v):
		bold = v
		queue_redraw()
## 足元の影。
var shadow := true:
	set(v):
		shadow = v
		queue_redraw()
## 縁取りの太さ（0 で無し）。
var outline := 0:
	set(v):
		outline = v
		queue_redraw()
var outline_color := Color(1, 1, 1, 0.9):
	set(v):
		outline_color = v
		queue_redraw()
## 白く光らせる量（0〜1）。当たったときの点滅など。
var flash := 0.0:
	set(v):
		flash = v
		queue_redraw()
## 見た目だけの伸び縮み。判定には効かない。
var squash := Vector2.ONE:
	set(v):
		squash = v
		queue_redraw()
## 見た目だけの傾き。判定には効かない。
var tilt := 0.0:
	set(v):
		tilt = v
		queue_redraw()

## 当たり判定の大きさ。ZERO なら字の大きさから決める。
var hit_size := Vector2.ZERO
## 判定の中心のずれ。
var hit_offset := Vector2.ZERO

## 字そのものの大きさ（描いたときの幅と高さ）。
var _box := Vector2.ZERO

static func font() -> Font:
	if _font == null:
		_font = load("res://fonts/NotoSansJP-Regular.otf")
	return _font

static func bold_font() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = font()
		_bold.variation_embolden = 0.9
	return _bold

## 手早く作る。
static func make(t: String, c := Color.BLACK, s := 22) -> Glyph:
	var g := Glyph.new()
	g.text = t
	g.color = c
	g.size = s
	return g

func _measure() -> void:
	var n := maxi(1, text.length())
	if vertical:
		_box = Vector2(size, size * n)
	else:
		_box = Vector2(size * n, size)

func box() -> Vector2:
	return _box

## 当たり判定（グローバル座標）。
func rect() -> Rect2:
	var hs := hit_size
	if hs == Vector2.ZERO:
		hs = _box * 0.8
	return Rect2(global_position + hit_offset - hs * 0.5, hs)

func touching(other: Glyph) -> bool:
	if other == null or not is_visible_in_tree() or not other.is_visible_in_tree():
		return false
	return rect().intersects(other.rect())

func _draw() -> void:
	if text == "":
		return
	var f := bold_font() if bold else font()
	draw_set_transform(Vector2.ZERO, tilt, squash)
	var chars: Array = [text] if not vertical else Array(text.split(""))
	var n := chars.size()
	for i in n:
		var s: String = chars[i]
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		## CJK の字は、基準線から 0.88em 上〜0.12em 下の枠に収まっている。
		## その真ん中が原点に来るように、基準線を 0.38em 下げる。
		var y := size * 0.38
		if vertical:
			y += (i - (n - 1) * 0.5) * size
		var pos := Vector2(-w * 0.5, y)
		if shadow:
			draw_string(f, pos + Vector2(1.5, 2.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.2, 0.12, 0.05, 0.22 * color.a))
		if outline > 0:
			draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_color)
		draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		if flash > 0.0:
			draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, flash * color.a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
