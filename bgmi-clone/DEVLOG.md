BGMI Clone - Dev Log
Ashutosh Naik | Oct 1-5, 2026

---

Day 1 — Getting started

Decided to make a third-person shooter for my CS project. Went with Godot 4 because it's free and I'd seen a few YouTube videos on it before. Took me a while to figure out the project structure — turns out Godot wants its own folder so I set it up inside a git repo.

First thing I got working was basic player movement. WASD felt fine pretty quickly. The harder part was the mouse look — kept getting weird bugs where the camera would snap or the character wouldn't rotate properly. Eventually figured out that mouse input has to go in _input() not _process() otherwise the camera jitters. Small thing but took me like an hour to get right.

Added sprinting, crouching, and jumping. Crouching was annoying because the collision capsule height has to update at the same time as the camera pivot, otherwise you clip through the floor or the camera flies up. Got it smooth with lerp.

Also added fall damage — if you fall fast enough you take damage proportional to the impact speed. Felt like a nice touch.

---

Day 2 — Shooting system

Got a gun mesh in the scene and figured out RayCast3D for hit detection. The raycast was hitting the player itself at first which was a bug — fixed it by excluding self from the raycast with add_exception().

Added a magazine system: 30 rounds in the clip, 90 in reserve. Reload animation was done by tweening the gun holder node position and rotation to simulate pulling the mag out, then snapping it back in after a timer.

Camera recoil on each shot was just clamping the camera pivot X rotation upward a bit per shot. Simple but looks decent.

Signals for health and ammo — health_changed and ammo_changed — so the HUD can update without the player directly touching UI nodes.

---

Day 3 — Bots and AI

This was probably the hardest part. I used NavigationAgent3D for pathfinding which required baking a navmesh in the editor. Baking it took a few tries because the arena mesh needs to be set as a navigation obstacle or the nav region doesn't cover it right.

Bot AI runs as a state machine: PATROL, CHASE, ATTACK, DEAD. Patrol picks a random point near the bot's spawn every few seconds. When it detects the player within range it switches to CHASE and moves toward them. When it gets close enough and has a clear shot it enters ATTACK.

The line-of-sight check was important — without it bots would just shoot through walls and boxes which was very obviously wrong. Fixed by firing the ShootRay at the player and checking if the collider IS the player node specifically. If something else is in the way (a box, a wall) the bot switches back to CHASE to go around it.

Bots tactically crouch when attacking from more than 4 meters away. When they die they tip over with a tween and drop loot.

---

Day 4 — Map, Character, Animations

Downloaded a low-poly FPS arena from Sketchfab and a character (The Boss) from Mixamo. Scaling the map to fit and getting the navmesh rebaked took a while.

The Sketchfab map had no physics collisions at all — it's just visual meshes. Wrote a script in main.gd that loops through every MeshInstance3D in the arena at startup and calls create_trimesh_collision() to auto-generate StaticBody3D colliders. That was a nice solution because I didn't have to set collisions on hundreds of individual meshes manually.

Animations from Mixamo come as separate FBX files for each action. Wrote a function that loads an FBX at runtime, pulls the animation data out of its AnimationPlayer, and adds it to the character's existing library under a custom name (run, crouch_idle, crouch_run). The animation switching in _physics_process checks current movement state and swaps animations accordingly, speeding up playback 1.4x when sprinting.

Bots use the same animation system.

---

Day 4-5 — Sound, Loot, Minimap

For SFX I used Python to generate simple procedural WAV files since I didn't have time to find proper royalty-free sounds — gunshot, footstep, reload, empty click, hit. They're rough but better than silence.

Footstep audio volume and pitch changes based on movement state: crouch is quiet (sneaky radius ~2.5m), walk is medium, sprint is loud (alert radius ~22m). Gunshots alert all bots within 55m. Bots react to sounds by switching to CHASE and navigating to where the sound came from.

Loot pickups are Area3D nodes that float and spin. Two types: medkits (+50 HP) and ammo crates (+60 rounds). Bots drop one randomly when they die. Five are also pre-spawned around the map at start.

The minimap in the top-right corner uses Godot's _draw() API on a Control node. It draws a circular radar — green arrow for the player, red blips for bots (with edge indicators if they're out of range), and colored dots for loot. Redraws every frame.

Alive counter tracks the bots group size in real time. When a bot dies it calls remove_from_group("bots") at the very start of die() so the count drops immediately.

Play Again button reloads the scene. The EndScreen visibility check in _input() stops the cursor from getting re-captured when the end screen is showing, which was breaking the restart button.

---

What I'd fix with more time

- Proper sound files instead of generated ones
- Bot difficulty scaling (they're a bit too accurate)
- More weapon types
- Better cover-peeking AI
- An actual main menu

Overall though it works — you can run around the warehouse, get shot at by bots that actually try to flank you, pick up loot, hear footsteps, and win or lose the match. Good enough for a 5-day project.
