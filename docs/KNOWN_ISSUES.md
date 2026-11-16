# Known issues

None of these block finishing a match.

| Issue | How to see it | Notes |
|---|---|---|
| Third-person camera pulls right in inside one-block tunnels | Dig a tunnel and walk in | It becomes near first-person and your sprite hides. Works, but V (first person) is nicer underground. |
| You cannot stand on a spring | Walk onto one | Any contact launches. Intended as a trap, awkward as furniture. |
| Team score can pass the goal | Bank 3 cheese when 1 short | Cosmetic: "9 / 8". |
| Bots never use abilities, gadgets or the workshop | Any match | On the cut list. They only dig, carry, bonk and bridge. |
| A badly stuck bot respawns | Rare; after about 24 s without moving | It leaves its cheese where it stood. |
| Loaded Free Build maps forget who owned TNT | F9 after placing TNT | Hitting it still lights it; remote detonate works for any charge in Free Build. |
| First editor open takes a moment | Open the project | Godot imports about 250 sprites and sounds once. |
| Machines are one block big | Place a crane | They read as toys rather than "heavy". Footprints larger than one cell would need multi-cell transport. |
| Pantograph skips gadgets | Copy a room with ladders | Only dirt, grass, stone, brick, ice, obsidian, painted blocks and glass are copied; the message says how many blocks were left out. |
| Chisel edits one microvoxel at a time | Carve a doorway | No brush sizes yet; big carvings are slow. |
| Bots ignore the new toys | Any match | They never use machines, Mobile TNT, chisel or pantograph. They do raid and defend vaults. |
| Bots treat carved blocks as solid | Carve a low tunnel | They dig through rather than use it. |
| Crane ball is hard to read from some angles | Man a crane | Hits show cracks and thuds, but the ball itself is small. |
| Online movement is trusted within a speed limit | A modified client | Digging, building, scores and inventories are server-validated; see docs/MULTIPLAYER.md "Limits". |
| Internet play from a player's PC needs port forwarding | Host behind a home router | UDP 24565. No relay or NAT punch-through yet; dedicated servers avoid this. |
| Server list has no player counts or ping | Play Online | It lists name, address and region from servers.json. |
| Unverified by a person | - | See "Not executed" in TEST_RESULTS.md: feel, audio levels, real-GPU frame rate. |
