# ROADMAP

Ordered by impact. When in doubt, pick whatever most improves how the game looks.

## Now
1. **Wanis, for real** — sculpted/procedural character mesh replacing the greybox
   proxy, with PBR + subsurface skin, rim lighting, and the prison/jacket two-state
   costume. The proxy is the single weakest thing on screen.
2. **Beauty benchmark: Brega Prison Breakout, one screen** — final shippable
   visual quality. Lighting, materials, atmosphere, hero. Everything later must
   match or exceed it. Do not move past this until it passes the quality gate.

## Next
3. Core systems: Sriracha bottles + trails, HEAT gauge, tuna sandwich lives,
   checkpoints, save data, HUD.
4. Chain Whip: attack + grapple, and the Brega transformation beat that unlocks it.
5. Level 1: Brega Prison Breakout, full level at benchmark quality, with its
   Iced Out Sriracha, first ice bonus level, and chain reward.
6. Juice pass: particles, hit-stop, camera, post, audio architecture.
7. Title screen, World 1 map, pause, settings, chain collection screen.

## After
8. Level 2: Ajdabiya
9. Level 3: Highway to Benghazi (vehicle)
10. Level 4: Garyounis University
11. Level 5: Benghazi + boss
12. More ice bonus levels, World 1 ending sequence
13. Endless polish passes

## Engineering debt worth paying early
- Audio architecture (buses, pooled players, surface-aware footsteps) before there
  is any audio to retrofit.
- Object pooling for collectibles and particles before the first dense level.
- A `docs/screenshots/` capture ritual on every visual commit so progress is visible.
