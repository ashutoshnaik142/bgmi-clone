# BGMI Clone

A third-person tactical shooter built in Godot 4. Made as a college project over ~5 days.

You spawn into a warehouse arena with 4 AI bots. Eliminate all of them before the 5-minute timer runs out, or die trying.

---

## Features

- Third-person over-the-shoulder camera
- WASD movement with sprint, crouch, and jump
- Automatic rifle with magazine system (30 rounds, 90 reserve), reload animation, and camera recoil
- Fall damage based on impact speed
- AI bots with patrol / chase / attack states and NavMesh pathfinding
- Bots check line-of-sight — they won't shoot through walls, they'll flank you instead
- Bots react to footsteps and gunshots (sound-based detection)
- 3D Mixamo character with run, crouch, and idle animations
- SFX for gunshot, footstep, reload, empty click, and hit
- Loot drops on bot death (medkit or ammo crate)
- Pre-spawned pickups around the map
- Minimap radar in the top-right corner
- Match timer, alive counter, and win/lose end screen
- Play Again button that fully resets the scene

---

## Requirements

- [Godot 4.3+](https://godotengine.org/download) (tested on 4.7.2 stable)
- Windows (tested), should work on Linux/macOS too
- GPU with Vulkan or D3D12 support (Forward+ renderer)

---

## Setup

1. **Clone the repo**
   ```
   git clone https://github.com/ashutoshnaik142/bgmi-clone.git
   cd bgmi-clone
   ```

2. **Open the project in Godot**
   - Launch Godot 4
   - Click **Import**
   - Navigate to `bgmi-clone/bgmi-clone/` (the nested folder — that's the actual Godot project)
   - Select `project.godot` and click **Import & Edit**

3. **Run the game**
   - Press **F5** or hit the Play button in the top-right
   - The main scene (`main.tscn`) will load automatically

> **Note:** The project uses the Terrain3D addon. If Godot shows errors about a missing plugin, go to **Project → Project Settings → Plugins** and make sure Terrain3D is enabled.

---

## Controls

| Action | Key |
|---|---|
| Move | W A S D |
| Look | Mouse |
| Sprint | Left Shift (hold, while moving forward) |
| Crouch | C (toggle) |
| Jump | Space |
| Shoot | Left Mouse Button (hold for auto) |
| Reload | R |
| Release cursor | Escape |

---

## Project Structure

```
bgmi-clone/
└── bgmi-clone/          ← Godot project root
    ├── player.gd        ← Player controller, movement, shooting, sound
    ├── player.tscn
    ├── bot.gd           ← Bot AI state machine, pathfinding, perception
    ├── bot.tscn
    ├── hud.gd           ← HUD updates (health, ammo, timer, alive count)
    ├── hud.tscn
    ├── match_manager.gd ← Match timer, spawn system, win/lose logic
    ├── main.gd          ← Arena collision setup, loot spawning
    ├── main.tscn        ← Main scene (arena + all nodes)
    ├── minimap.gd       ← Radar drawn with Godot's _draw() API
    ├── pickup.gd        ← Floating loot pickup (health / ammo)
    ├── pickup.tscn
    ├── audio/           ← Procedurally generated WAV sound effects
    ├── DEVLOG.md        ← Day-by-day development log
    └── addons/          ← Terrain3D plugin
```

---

## Known Issues

- Sound files are procedurally generated (not recorded), so they're a bit rough
- Bots can occasionally get stuck on complex geometry if the navmesh coverage is thin at edges
- No main menu — game starts immediately on launch

---

## Credits

- Character model: [Mixamo](https://www.mixamo.com/) — "The Boss"
- Arena map: [Low Poly FPS/TDM Game Map by Resoforge](https://sketchfab.com/) via Sketchfab
- Engine: [Godot 4](https://godotengine.org/)
- Physics: Jolt Physics (via Godot 4.3+ integration)
