class_name HintBar
extends Control
## Alt bilgi şeridi: "E: Konuş   ·   Esc: çık" gibi ipuçlarını tuş kapağı + açıklama olarak çizer.
## Tuşsuz parçalar (ör. "Sıran geldi!") vurgulu mesaj olarak gösterilir. text boşsa default_text (kontroller).

const HEIGHT := 18.0
const KNOWN_KEYS := ["WASD", "WASD / Oklar", "Sol/Sağ", "A/D", "Esc", "E", "T", "G", "H"]

var text := "":
	set(v):
		if v != text:
			text = v
			queue_redraw()
var default_text := ""
var accent := Color("4ade80")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(0, 270.0 - HEIGHT)
	size = Vector2(480, HEIGHT)


## Metni parçalara ayırır: [tuş, açıklama] (tuş yoksa "").
func _segments(s: String) -> Array:
	var out: Array = []
	for part in s.split("·"):
		part = part.strip_edges()
		if part == "":
			continue
		var i := part.find(": ")
		if i > 0:
			var key := part.substr(0, i)
			if key.length() <= 3 or KNOWN_KEYS.has(key) or "/" in key:
				out.append([key, part.substr(i + 2)])
				continue
		out.append(["", part])
	return out


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, 480, HEIGHT), UIDraw.BG)
	draw_rect(Rect2(0, 0, 480, 1), Color(UIDraw.GOLD, 0.7))
	draw_rect(Rect2(0, 1, 480, 1), Color(1, 1, 1, 0.05))
	var contextual := text != ""
	var segs := _segments(text if contextual else default_text)
	if segs.is_empty():
		return
	# toplam genişlik → ortala
	var widths: Array = []
	var total := 0.0
	for sg in segs:
		var w := 0.0
		if sg[0] != "":
			w += font.get_string_size(sg[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 7.0 + 4.0
		w += font.get_string_size(sg[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		widths.append(w)
		total += w
	total += 14.0 * (segs.size() - 1)
	var x := roundf((480.0 - total) / 2.0)
	for i in segs.size():
		var sg: Array = segs[i]
		if i > 0:
			draw_circle(Vector2(x - 7, HEIGHT / 2.0 + 1), 1.2, Color(1, 1, 1, 0.3))
		var cx := x
		if sg[0] != "":
			cx += UIDraw.keycap(self, Vector2(cx, 4), sg[0]) + 4.0
		var col := accent if contextual and (i == 0 or sg[0] == "") else Color(1, 1, 1, 0.82)
		draw_string(font, Vector2(cx, 12.5), sg[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		x += widths[i] + 14.0
