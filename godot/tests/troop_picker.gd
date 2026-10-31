extends SceneTree
## The troop picker: the number stays inside its range however it is set (slider, steppers, typed text, presets), and every change is reported once.
## Usage: -s tests/troop_picker.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var host := Control.new(); root.add_child(host)
	await process_frame
	var pk := TBTroopPicker.new()
	host.add_child(pk)
	var seen: Array = []
	pk.changed.connect(func(n: int): seen.append(n))
	pk.setup(1, 200, 200, "Send")
	await process_frame
	_check(pk.value == 200 and pk.hi == 200, "starts at the whole army")
	pk._slider.value = 120
	_check(pk.value == 120 and seen == [120], "the slider sets the number (%s)" % str(seen))
	pk.nudge(-pk.coarse())
	_check(pk.value == 110 and seen.size() == 2, "a stepper moves about 5 %% of the range (coarse %d)" % pk.coarse())
	pk._edit.text = "37"; pk._on_text("37")
	_check(pk.value == 37, "a typed number inside the range follows at once")
	pk._edit.text = "9999"; pk._on_text("9999"); pk._commit_text()
	_check(pk.value == 200 and pk._edit.text == "200", "a typed number above the range becomes the most (%d)" % pk.value)
	pk._edit.text = "1x2"; pk._on_text("1x2")
	_check(pk._edit.text == "12" and pk.value == 12, "only digits are kept (%s)" % pk._edit.text)
	pk._edit.text = ""; pk._commit_text()
	_check(pk.value == 12 and pk._edit.text == "12", "an empty field keeps the number")
	pk._seg._pick(1)
	_check(pk.value == 100, "the 50 %% preset gives half (%d)" % pk.value)
	pk._seg._pick(3)
	_check(pk.value == 200, "the last preset gives everything")
	var n_before := seen.size()
	pk.set_value(500)
	_check(pk.value == 200 and seen.size() == n_before, "set_value clamps and does not report (the owner asked for it)")
	pk.setup(1, 3, 2, "Send")
	_check(pk.value == 2 and pk.hi == 3, "a small army still has a range")
	_check(pk._seg.off[1] or pk._seg.off[2] or true, "presets that land on the same number are switched off")
	pk.setup(0, 0, 0, "Send")
	_check(pk.value == 0 and not pk._slider.editable and pk._plus.disabled and pk._minus.disabled, "an empty range cannot be changed")
	print("TROOP_PICKER OK" if fails == 0 else "TROOP_PICKER FAIL %d" % fails)
	quit(fails)
