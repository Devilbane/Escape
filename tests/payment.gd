extends SceneTree
## Paying copper prices with silver and gold, change in copper (see Payment).

var failed := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: ", what)


func _init() -> void:
	var p := Payment.plan(10, 50, 0, 0)
	check(p.kupfermuenze == 10 and p.change == 0 and p.silbermuenze == 0, "copper alone pays")
	p = Payment.plan(30, 5, 1, 0)
	check(p.kupfermuenze == 5 and p.silbermuenze == 1 and p.change == 0, "copper then silver, exact")
	p = Payment.plan(30, 0, 2, 0)
	check(p.silbermuenze == 2 and p.change == 20, "two silver for 30 give 20 change")
	p = Payment.plan(100, 0, 1, 1)
	check(p.silbermuenze == 0 and p.goldmuenze == 1 and p.change == 150, "silver short, one gold pays alone")
	p = Payment.plan(100, 0, 0, 1)
	check(p.goldmuenze == 1 and p.change == 150, "gold breaks into copper change")
	p = Payment.plan(300, 0, 20, 1)
	check(p.goldmuenze == 0 and p.silbermuenze == 12 and p.change == 0, "silver is used before gold")
	check(Payment.plan(300, 0, 1, 0).is_empty(), "too poor pays nothing")
	print("payment: ", "ok" if failed == 0 else "%d failed" % failed)
	quit(1 if failed else 0)
