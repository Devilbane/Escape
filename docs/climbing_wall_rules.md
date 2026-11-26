# How climbing works (rock faces and climbing walls)

Two things decide a climb: **Klettern** (the climbing skill, how likely each move is) and **Konstitution** (the breath meter, how long you last). Gear adds to Klettern.

## 1. What counts as your climbing level

`level = trained Klettern + worn gear + companion perks`

* Each worn piece of the set (hammer, rope, helmet, shoes, gloves) gives **+1**, the full set **+2 more** (so a full set is +7).
* Klettern grows by climbing: **2.0 training per metre** climbed (mountain rock; a wall gives half of that per metre).
* Hammer, rope and a nail in the bag let you set safe spots (nails). Without them every fall goes to the ground.

## 2. The mountain rock today (RockClimb, unchanged)

* One pull-up is 0.9 m. Chance = `0.62 + 0.05 x (your level - level the spot asks for)`, never below 40 % or above 95 %.
* A failed pull-up is a slip (try again at once), the second in a row a rest (4 s). Every failed try adds 20 % to the chance that a failure is a fall (max 85 %).
* A nail after 3 pull-ups in a row, then after every 2. A fall drops you to the last nail (the ground without one), 1.5 life per metre fallen, never lethal. 3 falls to a nail: you give up.

## 3. The climbing wall (new, same curve)

Every square you climb onto is one move.

1. **Level the square asks** = wall base level + the hold's malus (0 to 9) + weather (rain +2, snow +1, storm +3).
2. **Skill chance** = `0.62 + 0.05 x (your level - level asked)`, clamped to 40 to 95 % (the same curve as the rock).
3. **Square risk** (the part skill cannot remove) = the larger of
   * the surface: ice 18 %, loose stones 14 %, wet moss 9 % (wet moss x2 in rain and storm, ice x1.4 in snow and x1.3 in storm),
   * the weather floor: rain 5 %, snow 4 %, storm 8 % on every hold.
4. **Move chance** = skill chance x (1 - square risk). Because the risk is taken after the clamp, a master never gets above 95 % x (1 - risk): ice is at best 78 %.
5. **A failed move** is a slip, then a rest, then a fall with the rising fall chance of section 2. **Exception:** if the hands would have held (the roll is below the skill chance) and the surface took the hold, it is a fall at once.
6. **Gap jump** (a crack crossed along a row, from a hold with an arrow towards it):
   * needs level `wall base level + 3 per metre of width` (+3 in wind, +4 in storm, +1 in rain or snow); below that the jump cannot be tried,
   * chance = `55 % + 6 % per level above that` (max 92 %) x weather factor (wind 0.75, storm 0.6, rain and snow 0.9) x (1 - risk of the landing hold),
   * a missed jump is always a fall.
7. **Falling stones** (rain: one about every 16 s, storm: about every 5 s): a rattle and dust at the top of a column of the wall 1.5 s before the stone comes down. A climber in that column (and not braced) is knocked off with 50 % (6 life, a fall), otherwise grazed (3 life). Bracing (hold Space) takes nothing but you cannot move. Stepping out of the column in time avoids it.
8. **Weather changes during a climb** (in the game): every ~70 s it can turn one step worse (clear, wind, rain, storm), with a warning line, so a climb that starts in sun can end in a storm.

## 3b. Breath (stamina): Konstitution and the run meter

The climbing meter **is** the run meter (`Player.max_stamina`: Konstitution x 2 seconds, back at Konstitution / 10 per second), so a climb leaves the hero as winded as a long run. Konstitution is the key attribute here: it sets how many moves a climb can last, and Klettern sets how likely each move is.

* **Cost per move** (run-seconds): 1.0 per step, +0.25 per point of malus, +1.0 on ice, loose stones or moss, +0.5 in rain or snow (+1.0 in storm); a jump costs 3 plus 1 per metre of gap. Bracing against a falling stone costs 1.5 per second.
* **Rest:** hanging still gives the meter back. On the ground, at a nail or on an easy hold (malus 2 or less, no surface) it comes back **4x** as fast as running recovery; on any other hold only a quarter of the base rate.
* **Tired:** below 30 % of the meter every chance shrinks, down to 40 % of itself at empty (a 62 % move becomes 25 %).
* **Empty:** the next move is a fall ("your arms give out").
* Example: Konstitution 10 has 20 run-seconds. A malus-3 step costs 1.75, so about 11 such steps in a row; then rest on an easy hold (about 5 s for a full refill) or at a nail.

## 3c. Jumping: body and eye

- **Jump chance** uses a jump level = Klettern + (Geschick - 10) + (Intuition - 10) / 2. Plain steps ignore Geschick and Intuition.
- **Judging the gap**: the first push towards a gap is a look, not a jump. The climber rolls Weisheit + Intuition + Klettern
  (each above its start value 10, Klettern as is): the eye is good when a roll under 0.5 + 0.02 x level succeeds.
  A good eye shows the true chance as words: "looks doable" (80%+), "tight" (55%+), "risky" (30%+), "deadly".
  A poor eye is off by up to 35 points either way, so it can mislead. A very poor roll shows nothing at all.
- The second push jumps. Nothing forces the climber to; a missed jump always falls.

## 3d. Time, night and rest places

- Every move takes 15 minutes (a jump 18), catching breath on the wall (R) 24 minutes. The climb starts at 08:00.
- Moves cost more breath now (step 1.5, +0.4 per malus point, surface +1.5, jump +4 and 1 per metre; rain and snow +0.75, storm +1.5).
- From 18:00 the light fails: one level worse and 15% more breath per move. From 20:00 to 06:00 it is night: three levels worse and 40% more breath.
- A **rest place** (goal "Rastplatz", press R on it) lets the climber spend the night: they sleep until 06:00 and wake with a full meter.
  By day they rest three hours and get 70% of the meter back. The sample wall has rest places on the long, smooth route and one on the middle route; the short, hard route has none.
- Wolfram can climb a wall by himself ("Wolfram climbs (watch)" in the workshop): he plans the likeliest route, rests, spends the night at rest places, looks at each crack and turns back when it looks deadly.
- On the wall the hero and Wolfram shout: a grunt and a curse when a hold slips, a scream and an oath when a jump is missed or in a fall, a whoop at a landing (speech bubble and a sound made in code).

## 4. Example table (wall base level 3, clear weather, no surface)

| Hold malus | level 3 | 6 | 9 | 12 | 15 | 20 |
|---|---|---|---|---|---|---|
| 0 | 62 % | 77 % | 92 % | 95 % | 95 % | 95 % |
| 3 | 47 % | 62 % | 77 % | 92 % | 95 % | 95 % |
| 6 | 40 % | 47 % | 62 % | 77 % | 92 % | 95 % |
| 9 | 40 % | 40 % | 47 % | 62 % | 77 % | 95 % |

Same malus 3 with other conditions (level 6 / 12 / 20): ice 51 / 75 / 78 %, rain 49 / 78 / 90 %, storm 43 / 71 / 87 %.

| Jump width | level asked | at level 6 | 9 | 12 | 15 | 18 | 24 |
|---|---|---|---|---|---|---|---|
| 1 m | 6 | 55 % | 73 % | 91 % | 92 % | 92 % | 92 % |
| 2 m | 9 | - | 55 % | 73 % | 91 % | 92 % | 92 % |
| 3 m | 12 | - | - | 55 % | 73 % | 91 % | 92 % |
| 4 m | 15 | - | - | - | 55 % | 73 % | 92 % |

## 5. Open choices (to be decided)

* Konstitution is the only attribute (breath). Should it also add to the level? Proposed: no.
* Fall damage on the wall: proposed the same 1.5 life per metre as the rock.
* Should failed moves on a wall that the hero cannot afford (no hammer, rope, nail) fall to the ground? Proposed: yes, as on the rock.
