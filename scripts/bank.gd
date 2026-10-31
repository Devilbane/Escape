class_name Bank
extends RefCounted
## The bank of the crown in Lindenhain. Every hero has an account by name:
## gold paid in stays safe, and a rented vault in the cellar keeps the best
## treasures. The accounts are kept apart from the saved game, so every hero
## who ever played on this computer is in the books, and their vaults stand
## side by side in the cellar for anyone to look at through the bars.
## (Once there is a server, the accounts can live there instead.)

const FILE := "user://bank.json"
const VAULT_PRICE := 50
const VAULT_SIZE := 8

static var _data := {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_data = {"accounts": {}, "vaults": []}
	if FileAccess.file_exists(FILE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if parsed is Dictionary:
			_data.accounts = parsed.get("accounts", {})
			_data.vaults = parsed.get("vaults", [])


static func _save() -> void:
	var file := FileAccess.open(FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_data))


## Forgets what was read, so the next call reads the file again.
static func reload() -> void:
	_loaded = false


static func account(hero: String) -> Dictionary:
	_load()
	if not _data.accounts.has(hero):
		_data.accounts[hero] = {"gold": 0, "items": []}
	return _data.accounts[hero]


static func gold(hero: String) -> int:
	return int(account(hero).gold)


static func deposit(hero: String, amount: int) -> void:
	var acc := account(hero)
	acc.gold = int(acc.gold) + amount
	_save()


## Pays out as much as asked, or what is there; returns the amount.
static func withdraw(hero: String, amount: int) -> int:
	var acc := account(hero)
	var paid := mini(amount, int(acc.gold))
	acc.gold = int(acc.gold) - paid
	_save()
	return paid


static func has_vault(hero: String) -> bool:
	_load()
	return hero in _data.vaults


## Rents the next free vault in the cellar. The price comes from the account.
static func rent_vault(hero: String) -> void:
	_load()
	if not hero in _data.vaults:
		account(hero)
		_data.vaults.append(hero)
		_save()


## Vault holders in the order they rented, one per cell in the cellar.
static func vault_holders() -> Array:
	_load()
	return _data.vaults.duplicate()


static func vault_items(hero: String) -> Array:
	var items: Array = account(hero).get("items", [])
	account(hero).items = items
	return items


static func store(hero: String, id: String) -> bool:
	var items := vault_items(hero)
	if items.size() >= VAULT_SIZE:
		return false
	items.append(id)
	_save()
	return true


static func take(hero: String, index: int) -> String:
	var items := vault_items(hero)
	var id: String = items[index]
	items.remove_at(index)
	_save()
	return id
