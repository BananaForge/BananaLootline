🍌 BananaLootline

BananaLootline is a gear and loot planner for OctoWoW — a Vanilla 1.12 server running Mysteries of Azeroth. It answers the two most common questions while leveling: "What's worth upgrading?" and "Where do I go to get it?"

Part of the BananaForge addon collection.

📸 Screenshots
<table> <tr> <td><img src="screenshots/lootline.png" width="380" alt="Lootline view — upgrades grouped by location"/></td> <td><img src="screenshots/peritem.png" width="380" alt="Per item view — upgrade candidates for a single slot"/></td> </tr> <tr> <td align="center"><em>Lootline — upgrades grouped by location</em></td> <td align="center"><em>Per item — candidates for a single slot</em></td> </tr> <tr> <td><img src="screenshots/enchant.png" width="380" alt="Enchant tab — scored enchant suggestions per slot"/></td> <td><img src="screenshots/wheretogo.png" width="380" alt="Where to go — best dungeons and zones ranked by yield"/></td> </tr> <tr> <td align="center"><em>Enchant — scored suggestions per slot</em></td> <td align="center"><em>Where to go — locations ranked by upgrade yield</em></td> </tr> </table>
✨ Features
🔍 Automatic Equipment Scan

All 17 gear slots are scanned on login and on every equipment change. No manual entry needed.

📊 Stat Scoring

Tooltip-based stat parsing with English and German patterns. Stats are summed, scored against your class and detected spec, and compared to candidates in your level range.

⬆️ Upgrade Suggestions

Per-slot upgrade candidates with drop location, zone, and drop chance. Sorted by score delta — the biggest gains are always at the top.

🗺️ Lootline View

All upgrades grouped by location, sorted by total yield. Answers "where should I go?" instead of "which item is better for this slot?"

✨ Enchant Recommendations

111 enchants from the OctoWoW database, scored with the same weights as gear. Scope suggestions cover Back, Chest, Wrist, Hands, Legs, Feet, Main Hand and Ranged.

🎯 Spec Detection

Spec is read from GetTalentTabInfo. Weights shift accordingly. No spec is guessed below 10 talent points.

🛡️ Class & Armor Filtering

No staves for Hunters. No plate for Rogues. No two-handed axes for Mages. Armor type restrictions follow the 1.12 rules.

📍 Source Categories

Dungeon, Raid, World Boss, Battleground, Vendor, Quest, World — derived from instance group size, not a curated list. Level ranges are shown next to each location; the range turns orange if you can't enter yet.

🔮 Quest Rewards

Quests are placed by their quest giver, not dropped into a catch-all group. Opposite-faction quests are filtered out using pfQuest's race mask.

🔭 Forward Planning

Items above your level appear with a note instead of disappearing. /bll ahead <n> sets how many levels ahead to look.

🏆 Set Bonuses

A weaker individual piece can rank above a stronger one if it completes a set bonus. The score display shows where the advantage comes from.

⚡ Use Effects

Active effects are scored proportionally: 100 Attack Power for 20 seconds on a 120-second cooldown counts as ~17, not 100.

🔗 pfQuest Integration

Drop sources, vendors, quest givers, and chest locations are pulled live from pfQuest's database at runtime. No duplicate data, every pfQuest-octo update takes effect immediately.

💬 Tooltip Hook

Sources appear on every item tooltip in the game, not only inside the addon window.

📦 Installation
Extract the BananaLootline folder into <WoW directory>\Interface\AddOns\.
Install pfQuest and pfQuest-octo — source lookups require them. Everything else works without them. → pfQuest-octo by roby-brok
Log in and type /bll.

Note: The addon was renamed from OctoLootline to BananaLootline as part of the BananaForge collection. The TOC file will be updated in an upcoming release.

🎮 Commands
Command	Effect
/bll	Open / close the window
/bll up [n]	Search for upgrades, n = level range (default 6)
/bll spec	Show detected spec and talent points per tree
/bll ahead <n>	Levels ahead to plan for (default 6, 0 = equippable only)
/bll cat <Zone> <Category>	Reassign a location (dungeon, raid, worldboss …)
/bll unused	Toggle display of unreachable sources
/bll weight	Show or set stat weights
/bll stop	Cancel a running scan
/bll rate <n>	Scan rate in items/second (default 8)
/bll forget	Clear the item cache
/bll scan	Rescan equipment and print to chat
/bll dump <itemID>	Print raw tooltip lines and what was parsed — use this to debug patterns
/bll src <itemID>	Print sources of an item to chat
/bll info	Status line (pfQuest present? ItemDB? Locale?)
/bll debug	Toggle debug output
⚠️ Known Gaps
Stat weights in Weights.lua are placeholders. They separate "clearly better" from "clearly worse" but are not proper theorycraft. Use /bll weight to experiment.
Rings and cloaks are capped at 500 entries — the quality split doesn't apply there yet.
~170 weapons without a damage range (elemental damage only); DPS is present.
No cooldown data for use effects — cooldown is estimated.
Enchants are present but the deDE tooltip patterns need verification against a German client. Use /bll dump <itemID> to check and extend OLL.PATTERNS in Locale.lua.
🏗️ Architecture
BananaLootline.toc
Locale.lua              UI strings + tooltip patterns (deDE / enUS)
Data/ItemData.lua       Generated by importer — pure data, overwritten on update
Data/SetData.lua        Generated — sets and bonuses
Data/ZoneData.lua       Instance metadata — category, level range, abbreviation
Data/EnchantData.lua    Enchants per slot — maintained by hand
ItemDB.lua              Access layer for ItemData — never overwrite
SetDB.lua               Access layer for SetData
EnchantDB.lua           Enchant scoring
Weights.lua             Stat weights, use effects, scoring
Core.lua                Init, events, slash commands
Scanner.lua             Tooltip scan → stat table
Sources.lua             pfQuest adapter + tooltip hook
Gear.lua                Equipment and bag scan, export
Candidates.lua          Candidate search, data fetching, upgrade calculation
UI.lua                  Main window

tools/
  octodb_all.js         Browser snippet: fetch all items (66 filters)
  octodb_sets.js        Browser snippet: item sets and bonuses
  octodb_build.py       Exports → ItemData.lua + SetData.lua
  octodb_enchants.js    Browser snippet: collect enchants
  octodb_enchants_build.py  Export → EnchantData.lua
  octodb_import.py      Import pipeline
🧪 Real-World Testing Needed — Help Wanted!

This addon needs feedback from actual players.

My test character is currently level 15 and only covers Hunter. I have no real-world data on how the scoring, source detection, and upgrade suggestions hold up for other classes, specs, or higher level ranges.

What I need from you:

Does the scoring make sense for your class and level?
Are the source locations correct? Are drop chances plausible?
Are enchant suggestions reasonable for your gear level?
Does anything break at higher levels (30+, 40+, 50+)?
Are there upgrade candidates missing that you'd expect to see?

How to report:

The best bug reports include a screenshot showing what you saw and what you expected. Use the OctoWoW Bug Tracker or open a GitHub Issue here.

Helpful in-game commands before reporting:

/bll info       — shows addon version and data state
/bll dump <id>  — shows raw tooltip lines for an item
/bll debug      — enables verbose output in chat

Every piece of feedback improves the scoring for everyone. The addon is still young — your report genuinely matters.

📝 Credits

Source data from pfQuest and its data packages: Eric Mauser (Shagu), The Kludge Bureau, paokkerkir — combined in pfQuest-octo by Roby_Brok. MIT-licensed. This addon does not redistribute any of that data; it reads from pfDB at runtime.

Item data from the OctoWoW database (AoWoW-based).

Logo: Images/BananaForge.tga — 128×128 uncompressed TGA (required by the 1.12 client). Keep the same dimensions and format if you replace it; the client shows nothing — without an error — if the format is wrong.

BananaLootline is part of BananaForge — addon tools for OctoWoW.
