# ROADMAP

Ordered by impact. When in doubt, pick whatever most improves how the game looks.

## Now
1. **Bring Level 1 up to benchmark quality.** The level plays end to end but only
   section A is dressed to the standard of the beauty shot. B through F are
   correct geometry with the shared environment behind them and very little in
   front of or around them.
2. **The Iced Out warp and the first ice bonus level.** The secret bottle exists
   and is findable; touching it does nothing yet. This is the whole chain
   economy and none of it is built.
3. **Make the frame move.** Wind, sway and dust are implemented but read as
   nothing at the distances the camera uses. This is the difference between a
   diorama and a place.

## Next
4. Music: generative, maqam-derived, layered by level section.
5. Enemy variety: the wall turret and the heavy walker; hazards.
6. Title screen, pause, settings, World 1 map, chain collection screen.
7. Boss-grade set piece for the end of Brega, or move to Level 2.

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
