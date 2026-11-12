# Escape! online: the plan

Goal: many players in one world, and the game still works on the owner's home PC. A rented dedicated
server comes later, so the server must run on a home PC today and move to a host without a rewrite.

## The shape

One rule set, three ways to run it:

1. **Single-player (today, stays).** The game runs its own rules in-process. No network, no account.
2. **Home server.** The same rules run in a headless Godot process (`godot --headless`) on a PC; players
   connect over ENet or WebSocket. This is what the owner runs at home.
3. **Dedicated server.** The same headless export on a rented Linux host. Only the address, the
   database location and the TLS settings change; they come from a config file and command-line flags, never
   from code.

The client never changes the world. It sends **commands** (`scripts/sim/commands.gd`); the rules decide and
the client draws what comes back. Single-player uses the same path through an in-process server, so one code
path is tested.

## Rules that keep it portable

- No absolute paths, no `user://` writes inside rules code: storage goes through one `Storage` interface
  (files at home, a database later).
- Rules never touch nodes, the scene tree, `OS` or the wall clock. Time is `SimClock` ticks, randomness is
  `SimRng` streams (`scripts/sim/`).
- The server reads `server.cfg` (port, shard name, save folder, tick rate, max players) and flags; the same
  build runs anywhere.
- Home hosting needs a port forward or a relay; document it, and keep the protocol free of the host's address.

## Steps (each one a small PR that keeps the game playable)

1. **Foundations** (done): `SimRng`, `SimClock`, `Commands`, this plan, a test.
1. **Storage** (done for the bank, the house deeds and the ranking): `Storage` (`scripts/sim/storage.gd`)
   keeps shared records by name; the backend is files in the user folder at home, a server folder or a
   database later. `Training` (hero skills) moves over once the skill work settles.
1. **Home server skeleton** (done): `tools/server.gd` runs headless with `ServerConfig`; `NetServer` and
   `NetClient` (`scripts/net/`) handle hello, version, unique names, command checks and a rate limit.
   How to run it: [server.md](server.md).
1. **Versioned hero records** (started): `Game.hero_record()` builds the record a save file (or a server)
   keeps, and `SaveFormat.upgrade()` brings older records up to date step by step (`scripts/sim/save_format.gd`).
   A server keeps one record per hero with `HeroStore` and sends it with the welcome on login.
1. **Seeing each other** (done on the server side): games report their hero's place with a `where` command;
   `NetPresence` refuses impossible moves and tells each player who is near them (same map, within 60 m,
   at most 24) ten times a second. Drawing the others in the game comes with the first playable online mode.
2. **Rules out of `game.gd`**, one area at a time, behind the existing tests: inventory and bag, coins and
   bank, quests and bounties, reputation and factions, crafting, then combat resolution. Each becomes a plain
   class with `for_save()`/`load_from()` that `game.gd` calls. Coordinate with the skill and progression work so
   skills land in this shape.
3. **Versioned saves**: a migration chain, and one character record that is the same on disk and on the wire.
4. **Replace global `randi()/randf()`** in the rules with injected `SimRng` streams, area by area.
5. **Local server in-process**: the game sends commands to a `World` object and draws its events.
6. **Headless server and protocol**: ENet/WebSocket, login, snapshots, `server.cfg`, a bot client for load tests.
7. **Zones, interest management, shared monsters and loot rules, chat, parties, trading, market.**
8. **Dedicated host**: container image, database storage, backups, monitoring.

Each step lists its risks in its own PR. The biggest is step 2: `game.gd` is large and tightly coupled, so
extraction is done in slices that each pass the full test suite.
