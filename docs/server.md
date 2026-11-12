# Running an Escape! server

The server is the game itself, run without a window. The same command works on a home PC and,
later, on a rented Linux host; only the settings change.

```
godot --headless -s tools/server.gd -- --port=24570 --shard=Lindenhain --save-dir=user://server/
```

Settings, all optional (see `scripts/net/server_config.gd`):

| Setting | Command line | `server.cfg` (`[server]`) | Default |
|---|---|---|---|
| Port (UDP) | `--port=` | `port=` | 24570 |
| Most players at once | `--max-players=` | `max_players=` | 32 |
| Shard name | `--shard=` | `shard=` | Lindenhain |
| Where the books are kept | `--save-dir=` | `save_dir=` | `user://server/` |
| Another config file | `--config=` | | `server.cfg` beside the game |

The server keeps its own books (bank, house deeds, ranking) in its save folder through `Storage`, so
it never mixes them with the single-player game on the same PC.

## Playing over the internet from home

- Players on the same network connect to the PC's local address (for example `192.168.1.20`).
- For friends outside, forward the UDP port (24570) on the router to the PC, and allow it in the
  Windows firewall. They connect to the home's public address.
- A home connection usually carries a few dozen players. A rented server takes over when that is
  not enough: copy the save folder and start the same command there.

## What it does today

It lets players in (protocol version and a unique name), checks every command they send
(`Commands.check` and a rate limit) and answers each one. The world's rules move onto the server
step by step; see [the plan](mmo_plan.md).
