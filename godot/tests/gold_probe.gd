extends SceneTree
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", a[1]), {"seed": int(a[0])})
	var oe := g.nat_code.find(a[3])
	for t in range(1, int(a[2]) + 1):
		g.end_turn()
		if t % 5 == 0 or t == 1:
			var inc := g.income(oe)
			print("t=%d gold=%d net=%d provs=%d regime=%d stab(avg)=%d trade_cnt=%d keys=%s" % [t, int(g.gold[oe]), int(inc["net"]), g.own_count(oe), g.regime[oe], _avg(g, oe), g.trade_cnt[oe], str(inc.keys())])
	var inc := g.income(oe)
	print(inc)
	quit()
func _avg(g: TBGame, n: int) -> int:
	var s := 0; var c := 0
	for p in g.owned(n): s += g.stab[p]; c += 1
	return s / maxi(1, c)
