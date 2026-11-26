# Climbing animation sheet

Reference for every climbing animation (`RopeClimbPose`, `WallStage`, `ClimberRoute`, hero rock climbing). It combines the
user's own guide (Kletterbewegungen in der Steilwand) with real technique: feet drive the move, arms stay straight,
hips stay close to the wall, a short look and weight shift comes before every reach.
Render the poses with `tests/wall_move_sheet.gd` (`OUT=file.png xvfb-run -a godot --resolution 1800x1100 -s tests/wall_move_sheet.gd`).

| Sequence | Steps (from the guide) | Keys in `RopeClimbPose.KEYS` |
|---|---|---|
| Pull-up / vertical | hang, tension, body in, pull over the hands, reach higher, follow, foot on a higher step, stabilise; hands and feet work diagonally and offset in time | `pull_l`, `pull_r`: hang, look, reach, probe, sink (knee-bend wind-up), pull, hang |
| Traverse | lead hand reaches sideways, grip, hips follow close to the wall, back foot follows, front foot finds a step, weight over, second hand follows | `side_r` (left is the mirror): hang, look, sink, t_reach, t_grip, t_foot, t_over, t_shift |
| Sideways jump | knees bend and hips sink, turn to the target, push off, flight, both arms stretch to the target, catch, legs follow, land | `LEAP_POSES` in `wall_stage.gd`: crouch, spring |
| Fall and catch in the rope | slip, tip away, last grab, fall, rope taut, catch, swing, hang | `slip`, `fall`, `arrest` (the rope is drawn taut only at the catch) |
| Set up a stance | hammer pitons, clip the rope, check | `hammer`, `thread`; rest place: two pitons, hammock, sleep (`WallHammock`) |

Timing: slow looks and weight shifts (pauses), quick reaches. Feet stay planted while the body sinks (hips drop as far as the knees bend).
