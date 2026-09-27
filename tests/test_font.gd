extends "res://tests/helper.gd"
## スクリプトに書いた字が、すべて同梱のフォントに入っていること。
## パソコンでは OS のフォントが代わりに出るので気づかないが、
## Web 版には代わりが無く、豆腐（□）になってしまう。

func _scan(dir: String, out: Dictionary) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var src := FileAccess.get_file_as_string(dir + "/" + f)
			for i in src.length():
				var c := src.unicode_at(i)
				if c > 127:
					out[c] = dir + "/" + f
	for d in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + d, out)

func _test() -> void:
	var chars := {}
	_scan("res://scripts", chars)
	var font: Font = load("res://fonts/NotoSansJP-Regular.otf")
	var missing := []
	for c in chars:
		if not font.has_char(c):
			missing.append("%s（%s）" % [String.chr(c), chars[c]])
	check(missing.is_empty(), "すべての字がフォントにある %s" % [missing])
