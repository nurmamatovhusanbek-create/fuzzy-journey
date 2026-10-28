# Terra Bellum: security and foolproofing

What a player (or someone who is not a player) can try, what stops it, and what is left on purpose. Every row has a test (`godot/tests/security.gd`, `godot/tests/fuzz_commands.gd`, `tools/audit_links.py`).

## Trust model

| Mode | Who decides | Consequence |
|---|---|---|
| Single player | The player's own machine | Memory editors, edited saves and edited settings are the player's own business. The game only has to stay **stable** (never crash or corrupt on bad input). |
| Multiplayer | The server (`TBNet`, one authoritative `TBGame` per room) | A client is untrusted: it may only send *requests*. Nothing a client sends is applied without the server's own checks. |

## One door for every change: `TBCommands`

Every change to a game (the interface, the AI, the court's answers, the server) goes through `TBCommands.apply`. Before any command runs, `TBCommands.normalize` checks it against `TBCommands.SCHEMA`:

* the command is listed; every field is present with the right type (int/float/string), finite, in range (province `0..P-1`, nation `1..N`, quantities capped at 65000, ids at 24 characters);
* unknown keys are **dropped**, so nothing can be smuggled in;
* the engine-only switches `_force` (skip the AI's consent) and `_ult` are kept **only** for trusted callers (the AI, the court's answers, the server's own accepted proposals), and only as booleans;
* the target of a command is another living nation (not oneself; never the rebels for a pact).

The server uses the same function (`TBNet._sanitize`), so the interface and the server cannot disagree about what a command is. `n` (the acting nation) is **always set by the server from the sender's seat**, never read from the client.

`tests/fuzz_commands.gd` throws thousands of random, malformed and hostile commands at a running game and checks, after each batch, the state invariants (array sizes, owners in range, finite money, no gold / move points / manpower created by a command that should cost them). Before the schema it produced over a thousand script errors in 3000 commands; now it produces none.

## Multiplayer server

| Attack | Defence |
|---|---|
| Forcing an alliance, pact, marriage, trade or peace on another human | These always go through a **proposal** the other player must accept (marriage and trade were unilateral before). One open offer of a kind per pair, at most 4 per nation, deal kinds limited to white / vassal / cede. |
| Flooding commands, chat, room creation, joins | One token bucket per connection (15 actions/s sustained, burst 30); chat costs 4, joining 3, creating a room 10, picking a nation 2. |
| Guessing room codes | A join costs tokens, a wrong code counts, 8 wrong codes drop the connection. Codes are 5 of 32 letters/digits. |
| Hijacking a seat | Rejoining needs the 12-byte random token handed out at join; the old socket of the same seat is closed. A peer that was replaced or removed is nobody (`_room_of`), so a stale connection can no longer reach a room (it could crash the server before). |
| Many rooms | One room per connection, 50 rooms in all, idle rooms purged. |
| Idle or half-open sockets | Handshake must finish in 5 s; a connection that never creates or joins a room is dropped after 60 s; at most 200 connections; the server only accepts 64 KB per inbound message. |
| Holding the others up | With the turn clock on the server ends the turn. With it off, a player silent for 10 minutes counts as ready. A player who disconnects is replaced by the AI and gets the seat back with the token. |
| Text tricks in names and chat | Control characters, zero-width characters, bidi overrides and `[` `]` (rich-text markup) are removed; names 24 characters, chat 200; empty names become "Player". The client cleans again on receipt. |
| Bad data from the server (or a fake server) | Snapshots and updates are decoded with a hard 96 MB limit (a decompression bomb is refused), objects are never decoded, and a snapshot or update with the wrong shape or an index out of range is refused as a whole (nothing half applied). Only `ws://` and `wss://` addresses are accepted. |

### Known limit: no fog of war on the wire

Every client receives the whole world (armies, treasuries, plans) so a modified client can show what the interface hides. Closing that needs the server to send each player only what they see (a per-player delta), which changes the protocol and the cost of every turn. Until then fog of war in multiplayer is a courtesy, not a guarantee. This is the one big open item.

## Save files

* Slot names are reduced to letters, digits, `_` and `-` (no path can be made).
* A save is written to a temporary file, **read back and checked**, and only then swapped in; the previous good save is kept as `.bak`. A power cut or full disk can no longer destroy the only save, and a damaged main file falls back to the backup.
* Files over 48 MB are not read; objects are never decoded.
* A checksum (SHA-256 of the contents) detects damage and casual edits. It is not a secret and does not stop a determined editor; single-player saves are the player's own. Saves from before the checksum still load.
* On load every field is checked: wrong types or sizes, an unknown era or difficulty, owners or capitals that do not exist, or broken neighbour tables refuse the whole save (the player sees "unreadable", not a crash later); money that is not a number or absurdly large is repaired.

## Settings file

`user://settings.cfg` can be edited by hand. A value is taken only when it has the type of the default, sits inside its allowed set or range (volumes 0-100, text size 0.8-2.5, languages en/ru/uz, quality, view, effects...), and strings are at most 32 characters. Anything else falls back to the default. The saved multiplayer name is cleaned like any name.

## Content links

`tools/audit_links.py` (run by `tools/test_all.sh`) checks that every `res://` path exists, every translation key used in code exists in English, English / Russian / Uzbek have the same keys and the same `{placeholders}`, and no text is empty. It found the missing Uzbek ruler names (`rn_*`), now added.

## Not defended, on purpose

* Memory editing or a modded client in single player.
* A server operator reading or changing a room (they run the server).
* Denial of service at network level (a reverse proxy or the host's firewall is the right place; the server only limits what the game itself can be made to do).
