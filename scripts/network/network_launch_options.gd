class_name NetworkLaunchOptions
extends RefCounted


static func parse(arguments: PackedStringArray) -> Dictionary:
	var options := {
		"mode": "",
		"host": "127.0.0.1",
		"port": 7777,
		"instance": "",
		"slot": "",
		"name": "",
		"dedicated": false,
		"auto_ready": false,
		"auto_start": false,
		"debug_input": "",
		"debug_skip_hide": false,
		"debug_combat_test": false,
		"debug_tool_test": false,
	}
	for argument in arguments:
		if argument == "--server":
			options["mode"] = "server"
			options["dedicated"] = true
		elif argument == "--client":
			options["mode"] = "client"
		elif argument == "--dedicated":
			options["dedicated"] = true
		elif argument == "--auto-ready":
			options["auto_ready"] = true
		elif argument == "--auto-start":
			options["auto_start"] = true
		elif argument.begins_with("--debug-input="):
			options["debug_input"] = argument.trim_prefix("--debug-input=")
		elif argument == "--debug-skip-hide":
			options["debug_skip_hide"] = true
		elif argument == "--debug-combat-test":
			options["debug_combat_test"] = true
		elif argument == "--debug-tool-test":
			options["debug_tool_test"] = true
		elif argument.begins_with("--host="):
			options["host"] = argument.trim_prefix("--host=")
		elif argument.begins_with("--port="):
			options["port"] = clampi(
				int(argument.trim_prefix("--port=")),
				1,
				65535,
			)
		elif argument.begins_with("--instance="):
			options["instance"] = argument.trim_prefix("--instance=")
		elif argument.begins_with("--slot="):
			options["slot"] = argument.trim_prefix("--slot=")
		elif argument.begins_with("--name="):
			options["name"] = argument.trim_prefix("--name=")
	if str(options["name"]).is_empty():
		options["name"] = (
			str(options["instance"])
			if not str(options["instance"]).is_empty()
			else "玩家"
		)
	return options
