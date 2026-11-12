class_name SaveFormat
extends RefCounted
## The version of a hero's record (the saved game), and the steps that bring an
## older record up to date.
##
## A server keeps hero records for months while the game changes under them,
## and a home PC keeps old saves too. Every record carries "version"; when the
## record's shape changes, VERSION goes up by one and a step is added to
## STEPS that turns a record of the version before into one of the new
## version. `upgrade()` runs every step a record needs, in order, so the rest
## of the game only ever reads records of the current version.

const VERSION := 2

## version -> the method that turns a record of that version into the next.
const STEPS := {
	1: "_from_1",
}


## The record brought up to VERSION (a copy; the argument is not changed).
## A record from a newer game than this one is returned as it is, marked
## with "too_new" so the caller can refuse it instead of losing data.
static func upgrade(record: Dictionary) -> Dictionary:
	var data := record.duplicate(true)
	var version := int(data.get("version", 1))
	if version > VERSION:
		data.too_new = true
		return data
	while version < VERSION:
		data = Callable(SaveFormat, STEPS[version]).call(data)
		version += 1
		data.version = version
	return data


## Version 2 only starts the chain: version 1 records already hold
## everything, so nothing changes but the number.
static func _from_1(data: Dictionary) -> Dictionary:
	return data
