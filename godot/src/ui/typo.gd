## Typography: no widows. A paragraph never ends on a line of one or two words (a "tail" of three words at the least, as the design guide asks), whatever the language,
## the text size or the width. Three wrapping paths exist in the game and each calls this: a plain Label (the watcher below binds the last words with no-break spaces
## when, at the width it really has, the text would end on a short line), the Para (its own layout: `pull_tail`), and the chip text (`pull_tail` too).
class_name TBTypo
extends RefCounted

static var TLABELS_OFF := false
const NB := " "
const MIN_TAIL := 3                    # words on the last line
const SHORT := 0.5                     # ... unless the last line is already longer than this part of the width
static var off: bool = OS.get_environment("TB_NO_TYPO") != ""        # tests: the layout without the fix, to count what it repairs

## the watcher: every Label that wraps is looked at whenever it draws
static func install(tree: SceneTree) -> void:
	if tree.has_meta("typo") or off: return
	tree.set_meta("typo", true)
	tree.node_added.connect(_on_added)
	_walk(tree.root)

static func _walk(n: Node) -> void:
	_on_added(n)
	for c in n.get_children(): _walk(c)

static func _on_added(n: Node) -> void:
	if n is Label and not n.has_meta("typo"):
		n.set_meta("typo", true)
		var l: Label = n
		l.draw.connect(func(): _check.call_deferred(l))
		l.resized.connect(func(): _check.call_deferred(l))

static func _check(l: Label) -> void:
	if not is_instance_valid(l) or l.autowrap_mode == TextServer.AUTOWRAP_OFF or not l.is_visible_in_tree() or l is TBBz.TLabel and TLABELS_OFF: return
	var t: String = l.text
	if t != "" and l.size.x >= 60.0 and not (l is TBBz.TLabel): TBKit.fit_label_words(l)      # a word wider than the room is set smaller, never broken in the middle
	if t.length() < 20 or l.size.x < 50.0: return
	var key: String = "%s|%d" % [t, int(l.size.x)]
	if l.has_meta("typo_key") and l.get_meta("typo_key") == key: return
	var n: int = int(l.get_meta("typo_n", 0))
	if n >= 6: return                                        # a label that keeps being re-set by its owner is left alone (never a loop)
	var fixed: String = fix_text(t, l.get_theme_font("font"), l.get_theme_font_size("font_size"), l.size.x, l.autowrap_mode)
	if fixed != t:
		l.set_meta("typo_n", n + 1)
		if n == 5: print("TYPO: gave up on ", l.get_path(), " ", t.substr(0, 40))
		var vc: int = l.visible_characters
		l.text = fixed                                       # the label redraws and is looked at again with its new text
		l.visible_characters = vc                            # assigning a text resets this (a wrapped TLabel then draws nothing)
		var up: Node = l
		for i in 6:                                          # the rows around it re-measure (their height followed the old wrapping)
			if up is Control: (up as Control).update_minimum_size()
			up = up.get_parent()
			if up == null: break
		key = "%s|%d" % [fixed, int(l.size.x)]
	l.set_meta("typo_key", key)

## the text with the last words of each paragraph bound by no-break spaces, when at this width and font the paragraph would end on a short line
static func fix_text(t: String, font: Font, fs: int, width: float, mode: int) -> String:
	var paras: PackedStringArray = t.split("\n")
	var out := PackedStringArray()
	var flags: int = TextServer.BREAK_MANDATORY | (TextServer.BREAK_GRAPHEME_BOUND if mode == TextServer.AUTOWRAP_ARBITRARY else TextServer.BREAK_WORD_BOUND)
	if mode == TextServer.AUTOWRAP_WORD_SMART: flags |= TextServer.BREAK_ADAPTIVE
	for p in paras:
		out.append(_fix_para(p, font, fs, width, flags))
	return "\n".join(out)

static func _fix_para(p: String, font: Font, fs: int, width: float, flags: int) -> String:
	if p.length() < 12: return p
	var tp := TextParagraph.new()
	tp.add_string(p, font, fs)
	tp.width = width; tp.break_flags = flags
	var lc: int = tp.get_line_count()
	if lc < 2: return p
	var r: Vector2i = tp.get_line_range(lc - 1)
	var tail: String = p.substr(r.x, r.y - r.x).strip_edges()
	var tail_words: int = tail.replace(NB, " ").split(" ", false).size()
	if tail_words >= MIN_TAIL or tp.get_line_width(lc - 1) >= width * SHORT: return p
	# bind the last MIN_TAIL words (counting the ones already on that line)
	var words: PackedStringArray = p.split(" ")
	var real := 0
	for wd in words: real += _wc(wd)
	if real <= MIN_TAIL: return p
	for take in [MIN_TAIL, MIN_TAIL - 1]:                  # three words, or two when three do not fit
		var i: int = words.size(); var got := 0
		while i > 0 and got < take:
			i -= 1
			got += _wc(words[i])                           # a token already bound counts as the words it holds: fixing twice changes nothing
		var chain_s: String = NB.join(words.slice(i))
		if font.get_string_size(chain_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width * 0.92: continue
		var head := words.slice(0, i)
		return (" ".join(head) + " " + chain_s) if head.size() > 0 else chain_s
	return p

static func _wc(token: String) -> int:
	if token == "": return 0
	return token.split(NB, false).size()

## lines of words (Array of Array of String), measured by `wide(words) -> float`: the last line of a wrapped paragraph takes words from the line above until it holds MIN_TAIL
## (or the line above would be left with fewer than two, or the last line would not fit). Returns the same structure.
static func pull_tail(lines: Array, wide: Callable, width: float) -> Array:
	var n: int = lines.size()
	if n < 2 or off: return lines
	var last: Array = lines[n - 1]; var prev: Array = lines[n - 2]
	if last.size() >= MIN_TAIL or float(wide.call(last)) >= width * SHORT: return lines
	while last.size() < MIN_TAIL and prev.size() > 2:
		var cand: Array = [prev[prev.size() - 1]]
		cand.append_array(last)
		if float(wide.call(cand)) > width: break
		last = cand; prev = prev.slice(0, prev.size() - 1)
	lines[n - 1] = last; lines[n - 2] = prev
	return lines
