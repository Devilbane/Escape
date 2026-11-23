# Wind gust reference

The leaf motion in `scripts/wind_gusts.gd` follows a reference animation the project owner supplied
(`autumn-wind-overlay.gif`, 512x512, 120 frames at 30 ms, a transparent overlay of autumn leaves in a
strong wind). Measured by tracking the individual leaves frame by frame:

- Direction: left to right, a little downward (net angle about 9 degrees below horizontal).
- Speed: 10 to 16 px per frame (median 14), changing only mildly along a leaf's path (speed varies by
  about 17 percent).
- Wander: a leaf strays about 7 px sideways along its path and about 4 px up and down, the up-and-down
  bobbing at roughly 1.4 times a second.
- Flip: a leaf's visible area changes by about 50 percent as it turns, flipping edge-on and back about
  4 times a second.

The game keeps its own slower, floating gust (leaves rise, drift far along the wind and settle) and adds
the reference's quick flip (3 to 5 times a second), its bob (1.4 times a second) and its small surges.
