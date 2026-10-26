# BlackwellUI (BUI) // CYBERPUNK TACTICAL HUD FOR AZEROTH SURVIVORS

[![WoW Version](https://img.shields.io/badge/WoW-1.12.1%20Vanilla-blue.svg?style=flat-square)](https://github.com/Blackwellcode/BlackwellUI)
[![Game Mode](https://img.shields.io/badge/Mode-Azeroth%20Survivors-red.svg?style=flat-square)](https://github.com/Blackwellcode/BlackwellUI)
[![Release](https://img.shields.io/badge/Release-v2.6.4--azs-00e5ff.svg?style=flat-square)](https://github.com/Blackwellcode/BlackwellUI/releases)
[![Lua Engine](https://img.shields.io/badge/Engine-Strict%20Lua%205.0-brightgreen.svg?style=flat-square)](https://github.com/Blackwellcode/BlackwellUI)
[![License](https://img.shields.io/badge/License-MIT-orange.svg?style=flat-square)](https://github.com/Blackwellcode/BlackwellUI/blob/main/LICENSE)

> **BlackwellUI** is a lightweight, high-performance tactical HUD overhaul engineered from scratch specifically for the **Azeroth Survivors** game mode on World of Warcraft (Vanilla 1.12.1).

---

## ⚡ What is Azeroth Survivors & BlackwellUI?

**Azeroth Survivors** transforms World of Warcraft 1.12.1 into an adrenaline-fueled reverse bullet-hell / survival roguelite (*Vampire Survivors* style). Abilities trigger automatically, hordes of thousands of enemies swarm the arena, and millisecond build optimization decides victory or death.

Stock World of Warcraft UI (action bars, bag slots, micro menus, standard unitframes) is cluttered and counter-productive for this game mode. **BlackwellUI** completely purges all Blizzard UI overhead and replaces it with a razor-sharp tactical Cyberpunk HUD featuring 1px borders, dark translucent backdrops, Expressway typography, and real-time combat telemetry.

---

## 📸 In-Game Screenshots

### 1. Tactical Combat HUD (Naxxramas: The Scourge Invasion)
![BlackwellUI Combat HUD](media/screenshots/blackwell-hud-naxxramas.png)
*Full in-game combat HUD during a Naxxramas run. Centered Hero & Target frames with ability cooldown matrix, streamlined chat panel, economy telemetry DataBar, encounter radar and damage meter on the right, and the overhauled character sheet on the left.*

<br/>

### 2. Character Matrix & Run Stats Panel ('C' Key)
![Character Info & Run Stats](media/screenshots/blackwell-character-matrix.png)
*Redesigned Character Info window: Crisp 3D model frame, item quality border highlights, zero redundant bottom tabs, and the Azeroth Survivors Run Stats panel cleanly docked to the right edge.*

<br/>

### 3. Run Clock, Boss Schedule & Live Damage Meter
![Run Timer & Damage Meter](media/screenshots/blackwell-timer-meter.png)
*Live 20-minute run clock with boss spawn countdowns (Gates of Ahn'Qiraj: Kurinnaxx, General Rajaxx, Princess Huhuran, C'Thun) stacked directly above the Damage Meter featuring ability icons, dynamic equipped weapon textures, DPS rates, and the interactive `[R]` session reset button.*

---

## 🚀 Key Features & Telemetry Modules

* **Zero-Clutter Philosophy:** Blizzard action bars, bags, and micro buttons are permanently hidden and suppressed. 100% of your screen is dedicated to combat visibility and threat tracking.
* **Consolidated Combat Meter & Multiplayer Drilldown (`Meter.lua`):** 5 selectable modes (**Damage Done**, **Boss Damage**, **Healing Done**, **Damage Taken**, **Party Damage**) with instant header tab switching.
  * **Legendary Neck & Proc Merging `[M]`:** Quick header toggle button and GUI option to aggregate compound item procs (e.g. `Amulet of the Inferno: Consecration`) directly into their parent spell totals. Hovering reveals a complete breakdown of Direct Casts vs Procs + source items.
  * **Accurate Damage Share % & Relative Bar Scaling:** Displays true calculated damage share percentages (e.g. 34%, 24%, 4.2%) with statusbars filled proportionally relative to the top #1 ability (`d / maxVal`).
  * **Party Drilldown:** In Party mode, click any party member to view their individual abilities, hit counts, crits, and DPS.
  * **Session Reset `[R]`:** Left-Click resets session numbers & crits to 0; Right-Click restores full run totals.
* **Top Buff & Upgrade Telemetry Bar (`Build.lua`):** Sleek, non-intrusive buff and passive upgrade row docked directly above your abilities. Features an 8-stage spell resolution engine resolving missing spell names, racials (Perception, Blood Fury, Will of the Forsaken, Berserking), and tier bonuses with full tooltips.
* **Tactical Minimap & Radar Pins (`Pins.lua` / `Minimap.lua`):** Clean square minimap with dark 1px border. Background red cross texture and redundant stock buff icons permanently suppressed. Real-time Chebyshev edge-clamped spatial tracking for Caches (`AZS_CHESTS`) and Guardian Lairs (`AZS_GetLairs`) with distance in yards and breathing beacon animations.
* **Centered Cooldown Manager & Real-time DoT Counter (`Build.lua`):** 36×36px spell tiles with dark cooldown swipe overlays, active rank badges, full ability tooltips, and **live DoT/Debuff counters** displaying active targets for bleeds (Rend, Deep Wounds), demoralizing shouts, fears, and totems.
* **Stored Level-Up Quick Button & Auto-Suppression:** When *Store Level-Ups* is active, a glowing Cyberpunk `[ LEVEL UP READY (N) - PRESS Y ]` button surfaces right above your ability tiles for instant 1-click access (`AZS_OpenStoredLevels`). Stock default level-up icon is automatically suppressed to prevent duplicate on-screen elements.
* **Streamlined Character & Inspect Matrix (`Character.lua`):** Redesigned Character and Inspect windows featuring a crisp 3D model frame, item quality border highlights, zero redundant bottom tabs, and the Azeroth Survivors Run Stats panel cleanly docked to the right edge. Redundant base attributes and item level clutter are stripped for an unobstructed view.
* **Guardian 8:00 Speedrun Tracker (`Timer.lua`):** Integrated live goal tracker inside the run timer monitoring the *"Slay 4 Guardians before 8:00"* speedrun achievement with status (`ACHIEVED`, countdown timer, or `EXPIRED`).
* **Kill Pace Telemetry (`DataBar.lua`):** 20-second rolling kill rate indicator in the bottom telemetry bar (`[85/m]`), dynamically color-coded by performance tier (Blazing Green, Fast Cyan, Steady Amber, Muted Red).
* **Loot Drop Telemetry Log (`Loot.lua`):** Compact, draggable feed capturing item drops from `CHAT_MSG_LOOT` with WoW quality colors (Gray to Legendary), run timestamps (`[04:12]`), and interactive hyperlink inspection.
* **Chat Spam Filter (`Chat.lua`):** Silently suppresses repetitive `Congratulations, you have reached level X!` and subsequent `+X% stat` spam floods to keep your communication pristine.
* **Target Debuff Aura Bars:** Stacks debuff bars directly above your target frame with square spell icons, spell names, remaining durations, and centered ticking damage values.
* **Cyberpunk Nameplates:** 120×10px statusbars, 1px contrast borders, neon reaction coloring (Hostile Red, Neutral Gold, Friendly Green), and dynamic accent borders for your active target.
* **Elites & Bosses Radar:** Tracks bosses, guardians, and elites in real-time with remaining HP and percentages. Supports **click-targeting** directly from the tracker row.
* **Live Stat Multipliers:** Displays active player multipliers (Damage, Cooldown Reduction, Crit, Area, Echo, Speed) parsed directly from `AZS_STATS`. Automatically hides when the Character Frame is opened to avoid screen overlap.

---

## ⌨️ Quick Controls & Commands

| Command | Action |
|---|---|
| `/bw` or `/bui` | Toggle the BlackwellUI Control Center (Themes, Accent Colors, Font Scale) |
| `/bw unlock` or `/bw move` | Unlock all HUD frames for drag-and-drop repositioning |
| `/bw lock` | Lock all HUD frames in place |
| `/bw reset` | Reset all frames to default screen layout |
| `/bw demo` | Toggle demo/preview mode with simulated combat data |
| `/bw hud` | Toggle replacement of the stock Azeroth Survivors run HUD |
| `/bw pins` | Toggle Minimap Radar Pins (Caches & Guardian Lairs) |
| `/bw loot` | Toggle the real-time Loot Drop Telemetry Log |

---

## 🔗 Links & Resources

* **GitHub Repository:** [github.com/Blackwellcode/BlackwellUI](https://github.com/Blackwellcode/BlackwellUI)
* **Releases & Downloads (`BlackwellUI.zip`):** [github.com/Blackwellcode/BlackwellUI/releases](https://github.com/Blackwellcode/BlackwellUI/releases)
* **Game Mode:** Azeroth Survivors (Custom Vanilla 1.12.1 Client)
* **Issue Tracker & Feature Requests:** [github.com/Blackwellcode/BlackwellUI/issues](https://github.com/Blackwellcode/BlackwellUI/issues)

---

## 🛡️ Engineering Standard

* **100% Strict Lua 5.0:** Engineered specifically for the WoW 1.12.1 client core (no `#` length operators, no `%` modulo operators, no string method calls).
* **Zero Texture Leaks:** Idempotent border and backdrop management (`buiEdges` caching), eliminating texture duplication and memory bloat.
* **Zero Hallucination Defensive Architecture:** Safe function-type checks across all Azeroth Survivors globals (`AZS_*`), guarded spellbook scanners, and plain-string substring matching to prevent regex pattern crashes.
