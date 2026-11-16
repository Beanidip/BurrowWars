# Known issues

None of these block finishing a match.

| Issue | How to see it | Notes |
|---|---|---|
| Third-person camera pulls right in inside one-block tunnels | Dig a tunnel and walk in | It becomes near first-person and your sprite hides. Works, but V (first person) is nicer underground. |
| You cannot stand on a spring | Walk onto one | Any contact launches. Intended as a trap, awkward as furniture. |
| Team score can pass the goal | Bank 3 cheese when 1 short | Cosmetic: "9 / 8". |
| Bots can mine a cheese block through a thin wall | Watch a bot next to a ruin wall | They mine within 2.1 blocks without a line-of-sight check. |
| Bots never use abilities, gadgets or the workshop | Any match | On the cut list. They only dig, carry, bonk and bridge. |
| A badly stuck bot respawns | Rare; after about 24 s without moving | It leaves its cheese where it stood. |
| Loose cheese sinks in water | Drop cheese in the pond | It rests on the bottom; you can still swim down for it. |
| Water and lava do not flow | Dig next to a pond | Static liquids (cut list). |
| Loaded Free Build maps forget who owned TNT | F9 after placing TNT | Hitting it still lights it; remote detonate works for any charge in Free Build. |
| First editor open takes a moment | Open the project | Godot imports about 250 sprites and sounds once. |
| Unverified by a person | - | See "Not executed" in TEST_RESULTS.md: feel, audio levels, real-GPU frame rate. |
