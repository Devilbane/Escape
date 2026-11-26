extends SceneTree
## Makes the entry of a riddle (see RiddleVault) for source code. The answer and the code come from the environment,
## not from the command line or a file, so they stay out of shell history and the repository:
##   RIDDLE_ANSWER="the words" RIDDLE_CODE="3,17,0,5" godot --headless -s tools/riddle_hash.gd
## Prints the salt, rounds and hash, and the scrambled code. Never paste the answer into a commit, test or PR text.


func _initialize() -> void:
	var answer := OS.get_environment("RIDDLE_ANSWER")
	if answer == "":
		print("Set RIDDLE_ANSWER (and RIDDLE_CODE, numbers separated by commas, if the riddle has a code).")
		quit(1)
		return
	var entry := RiddleVault.make_entry(answer)
	print('const ENTRY := {"salt": "%s", "rounds": %d, "hash": "%s"}' % [entry["salt"], entry["rounds"], entry["hash"]])
	var code_text := OS.get_environment("RIDDLE_CODE")
	if code_text != "":
		var code: Array = []
		for part in code_text.split(","):
			code.append(int(part))
		print('const CODE := "%s"' % RiddleVault.scramble(code, entry))
	quit()
