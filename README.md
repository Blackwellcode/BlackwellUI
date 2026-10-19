# BlackwellUI (BUI)

[![WoW Version](https://img.shields.io/badge/WoW-1.12.1%20Vanilla-blue.svg)](https://github.com/Seele2024/BlackwellUI)
[![Game Mode](https://img.shields.io/badge/Mode-Azeroth%20Survivors-red.svg)](https://github.com/Seele2024/BlackwellUI)
[![Release](https://img.shields.io/badge/Release-v2.0.0--azs-00e5ff.svg)](https://github.com/Seele2024/BlackwellUI/releases)
[![Lua](https://img.shields.io/badge/Lua-5.0%20Strict-brightgreen.svg)](https://github.com/Seele2024/BlackwellUI)

**BlackwellUI (BUI)** is a stripped-down, high-performance tactical HUD engineered from scratch specifically for the **Azeroth Survivors** game mode on World of Warcraft (Vanilla 1.12.1).

Designed with a high-contrast Cyberpunk aesthetic (1px borders, dark semi-translucent panels, Expressway typography), BlackwellUI eliminates stock clutter and equips you with real-time combat analytics to maximize survival and DPS.

---

## 🩸 Core Features

* **Purged Stock Clutter:** Unused action bars, bag frames, and micro menus are completely suppressed. Since abilities auto-cast in Survivors, your screen space is dedicated solely to combat intelligence.
* **Centered Cooldown & Build Matrix:** 36×36 square spell tiles with radial cooldown swipes, active rank indicators, and clean typography centered right between your hero and target frames.
* **Smart Aura Buff Tracker:** Real-time proc and aura tracking with crisp square spell icons, resolved spell names (no raw numeric IDs), and full-width color-coded statusbars matching spell schools.
* **Dynamic Encounter Radar:** Boss, guardian, and elite tracking docked cleanly under the minimap showing live HP, maximum health, and remaining percentage without frame overlap.
* **Combat Telemetry Suite:**
  * **Damage Meter:** Integrated Done/Taken meter with ability icons, DPS rates, and share percentages.
  * **Stat Multipliers:** Live left-side panel displaying active character multipliers (Damage, Area, CDR, Crit, etc.) parsed directly from `AZS_STATS`.
  * **Economy DataBar:** Bottom telemetry strip displaying XP progress, Level, Kills, Gold, **Next Chest Cost**, Lives, Rerolls, FPS, and Network Latency.
* **Minimalist Cyberpunk Styling:** 1px borders, customizable semi-transparent backdrops, modern fonts (*Expressway*, *Homespun*, *Fira Sans*), and smooth statusbars.

---

## 🎛 Controls & Commands

Access all settings in-game via the configuration window:

| Command | Action |
|---|---|
| `/bui` or `/blackwell` | Toggle the BlackwellUI Configuration Center |
| `/bui unlock` or `/bui move` | Unlock all HUD frames for drag-and-drop repositioning |
| `/bui lock` | Lock all HUD frames in place |
| `/bui reset` | Reset all frames to default layout |
| `/bui demo` | Toggle demo/preview mode |
| `/bui hud` | Toggle replacement of stock Azeroth Survivors run HUD |

### Configuration Center
* **Themes:** Select from preset themes (*Blackwell Cyan*, *Crimson*, *Amber*, *Emerald*, *Violet*, *Monolith*, *Class Colors*) or click the **RGB Swatch** to pick any custom accent color using the native Blizzard color picker.
* **Fine-Tuning:** Dedicated step controls for Frame Backdrop Opacity (30%–100%), HUD Font Scaling (`-2` to `+4`), and Chat Font Size (`8pt` to `20pt`).

---

## 📥 Installation

1. Download the latest repository code or Release ZIP.
2. Ensure the extracted folder is named exactly **`BlackwellUI`** (do not leave it as `BlackwellUI-main`).
3. Move the `BlackwellUI` folder into your game directory:
   ```text
   World of Warcraft/Interface/AddOns/BlackwellUI
   ```
4. Verify the folder contains `BlackwellUI.toc`, `Core.lua`, `media/`, etc.
5. Log into World of Warcraft (Vanilla 1.12.1) and ensure **BlackwellUI** is enabled in the AddOn menu.
6. Type `/bui` in-game to configure your setup!

---

## 🛠 Engineering & Compatibility

* **Vanilla 1.12.1 / Lua 5.0 Strict:** 100% compliant with Lua 5.0 specifications (no `#` length operators, no `%` modulo, no string method calls, zero post-1.12 APIs).
* **Safe CVars Management:** Safely toggles persistent stock HUD CVars with zero redundant `SetCVar` loops.
* **Backwards Compatibility:** Includes automated SavedVariables migration and slash command aliases for smooth upgrades.

---

## 📜 License

Created by **Pierre** & **Ellesmere** for the Azeroth Survivors community. Released under the MIT License.
