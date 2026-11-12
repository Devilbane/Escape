class_name Storage
extends RefCounted
## Where the shared books live: the bank, the house deeds, the ranking.
##
## Today they are JSON files in the user folder of this computer. A server
## keeps them somewhere else (its own folder at first, a database later), so the
## code that owns the books never opens a file itself: it reads and writes a
## record by name here, and the backend decides where it goes.
##
## `Storage.read(name)` returns the parsed JSON (null when there is none) and
## `Storage.write(name, value)` stores it. `Storage.use(backend)` swaps the
## backend: `Storage.Files.new(folder)` or `Storage.Memory.new()`.


## A backend: records by name.
class Backend:
	extends RefCounted

	func read(_name: String):
		return null

	func write(_name: String, _value) -> bool:
		return false


## Records as `<folder><name>.json` files. The default folder is the user
## folder, where the books have always been.
class Files:
	extends Backend

	var folder := "user://"

	func _init(where := "user://") -> void:
		folder = where if where.ends_with("/") else where + "/"

	func path(name: String) -> String:
		return folder + name + ".json"

	func read(name: String):
		var file := path(name)
		if not FileAccess.file_exists(file):
			return null
		return JSON.parse_string(FileAccess.get_file_as_string(file))

	func write(name: String, value) -> bool:
		DirAccess.make_dir_recursive_absolute(folder)
		var file := FileAccess.open(path(name), FileAccess.WRITE)
		if file == null:
			return false
		file.store_string(JSON.stringify(value))
		file.close()
		return true


## Records kept in memory only: for tests and for a server that has not been
## given a folder. Values go through JSON, as they would on disk.
class Memory:
	extends Backend

	var records := {}

	func read(name: String):
		return JSON.parse_string(records[name]) if records.has(name) else null

	func write(name: String, value) -> bool:
		records[name] = JSON.stringify(value)
		return true


static var _backend: Backend = null


static func backend() -> Backend:
	if _backend == null:
		_backend = Files.new()
	return _backend


## Swaps where the books are kept (null goes back to the user folder).
static func use(which: Backend) -> void:
	_backend = which


static func read(name: String):
	return backend().read(name)


static func write(name: String, value) -> bool:
	return backend().write(name, value)
