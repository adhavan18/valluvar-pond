class_name Data
extends RefCounted
## The Kurals, the word pool the games draw from, and the wisdom the player has earned.

static var kurals: Array = []
static var word_pool: Array[String] = []
static var wisdom := 0
static var best_fishing := 0
## Ids of the Kurals completed in any game.
static var collected := {}

static func load_all() -> void:
	var f := FileAccess.open("res://data/kurals.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	kurals = parsed
	var seen := {}
	for k: Dictionary in kurals:
		for w in words(str(k["ta"]).replace("\n", " ")):
			if w.length() >= 3 and not seen.has(w):
				seen[w] = true
				word_pool.append(w)
	var cfg := ConfigFile.new()
	if cfg.load("user://save.cfg") == OK:
		best_fishing = int(cfg.get_value("game", "best", 0))
		wisdom = int(cfg.get_value("game", "wisdom", 0))
		for id in cfg.get_value("game", "collected", []):
			collected[int(id)] = true

static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", best_fishing)
	cfg.set_value("game", "wisdom", wisdom)
	cfg.set_value("game", "collected", collected.keys())
	cfg.save("user://save.cfg")

static func collect(k: Dictionary) -> void:
	collected[int(k["id"])] = true

## The words of a line, without punctuation.
static func words(line: String) -> Array[String]:
	var out: Array[String] = []
	for raw in line.split(" ", false):
		var w := raw.strip_edges().trim_suffix(".").trim_suffix(",").trim_suffix(";")
		if w != "":
			out.append(w)
	return out

static func lines_of(k: Dictionary) -> PackedStringArray:
	return str(k["ta"]).split("\n")

static func label_of(k: Dictionary) -> String:
	return "Kural %d · %s" % [int(k["id"]), str(k["chTa"])]
