class_name Enemy
extends CharacterBody3D
## A skeleton guard. Warriors run at the hero and strike with a blade,
## archers keep their distance and shoot crossbow bolts, mages cast magic
## orbs that curve after the hero, minions are small, quick and frail, and
## brutes are big, slow and hit twice as hard. A guardian wears armour no
## blade gets through: only a stab in the back, before it has noticed the
## hero, brings it down. It stands still and watches what it guards.
## Any skeleton that has not noticed the hero falls to such a stab at once.
##
## Out in the open the same class runs the bandits of the robbers' pass:
## people, not bones, in the adventurer models. They roam around their camp
## instead of standing guard, taunt the hero instead of groaning, and drop
## gold and gear when they fall (see Outdoor).
##
## Beasts live in the wild too: wolves, orcs, spiders and a yeti in the hollow north
## of the pass. They are animals and monsters with models of their own, so
## each kind maps the animation names this class plays onto its model's own
## ("anims"), and they hold no weapons and wear no clothes.
##
## Not all of them are on the same side (see Factions): when rivals meet,
## say a wolf and a bandit, or a skeleton and a bat of the dragon's brood,
## they fight each other ("foe"). A faction the hero has won over leaves the
## hero alone and falls upon monsters that hunt the hero nearby.

signal died

const SIGHT := 26.0
## Noticing the hero. Eyes look ahead in a 120 degree cone and need light on
## the hero (a burning torch nearby, or the lantern when not sneaking). Ears
## hear all around, but not a hero who sneaks or stands still. Right up
## close, a skeleton always notices.
const SIGHT_CONE := deg_to_rad(60.0)
const HEARING := 10.0
const TOUCH := 2.2
## Seconds a hunting skeleton searches after losing the hero before it gives up.
const GIVE_UP := 5.0
## A guardian never strays farther than this from its post: it breaks off
## the hunt and walks back, so running out of its hall always works.
const LEASH := 14.0
const POISON_CHANCE := 0.25
## Model, weapon, life, speed, damage, reach, scale and pause between attacks.
## "armor" is the kind's own hardening (thick bones, hide or leather), on top
## of what its worn gear adds.
const KINDS := {
	"krieger": {"model": "Skeleton_Warrior", "weapon": "Skeleton_Blade", "hp": 3, "speed": 4.8, "damage": 1, "reach": 2.0, "size": 1.0, "cooldown": 1.4},
	"schuetze": {"model": "Skeleton_Rogue", "weapon": "Skeleton_Crossbow", "hp": 2, "speed": 3.6, "damage": 1, "reach": 22.0, "size": 1.0, "cooldown": 2.4, "ranged": true},
	"magier": {"model": "Skeleton_Mage", "weapon": "Skeleton_Staff", "hp": 2, "speed": 3.4, "damage": 1, "reach": 20.0, "size": 1.0, "cooldown": 3.0, "ranged": true},
	"wicht": {"model": "Skeleton_Minion", "weapon": "Skeleton_Blade", "hp": 1, "speed": 6.4, "damage": 1, "reach": 1.8, "size": 0.8, "cooldown": 1.0},
	"koloss": {"model": "Skeleton_Warrior", "weapon": "Skeleton_Axe", "shield": "Skeleton_Shield_Large_A", "hp": 7, "speed": 3.3, "damage": 2, "reach": 2.5, "size": 1.5, "cooldown": 2.0, "armor": 1, "tint": Color(0.72, 0.42, 0.34)},
	# Fog wraiths drift among the dead trees above ground, only in fog (see
	# Weather): pale little dead that roam instead of standing guard.
	"fog_wraith": {"model": "Skeleton_Minion", "weapon": "Skeleton_Blade", "hp": 2, "speed": 5.6, "damage": 1, "reach": 1.8, "size": 0.9, "cooldown": 1.1,
		"tint": Color(0.78, 0.86, 0.95), "roam": true, "voice": ["voice_wicht", 0.75, "huuu"], "purse": [1, 3]},
	"waechter": {"model": "Skeleton_Warrior", "weapon": "Skeleton_Axe", "shield": "Skeleton_Shield_Large_A", "hp": 1, "speed": 3.0, "damage": 2, "reach": 2.3, "size": 1.25, "cooldown": 1.6, "tint": Color(0.46, 0.5, 0.58), "armored": true},
	# The bandits of the open wild: "human" kinds use the adventurer models
	# ("dir"), keep only the body parts in "parts", wear clothes in "colors"
	# (body, legs, hat or cape) and "roam" around where they were placed.
	"halsabschneider": {"model": "Rogue", "dir": "characters", "weapon": "dagger", "hp": 3, "speed": 5.2, "damage": 1, "reach": 1.9, "size": 1.0, "cooldown": 1.1,
		"human": true, "roam": true, "parts": ["Rogue_Cape"], "colors": [Color(0.32, 0.3, 0.28), Color(0.28, 0.24, 0.2), Color(0.22, 0.2, 0.18)]},
	"wilderer": {"model": "Rogue", "dir": "characters", "weapon": "Skeleton_Crossbow", "hp": 2, "speed": 4.0, "damage": 1, "reach": 20.0, "size": 1.0, "cooldown": 2.6, "ranged": true,
		"human": true, "roam": true, "parts": [], "colors": [Color(0.3, 0.42, 0.26), Color(0.36, 0.3, 0.22), Color(1, 1, 1)]},
	"schlaeger": {"model": "Barbarian", "dir": "characters", "weapon": "axe_1handed", "hp": 6, "speed": 3.8, "damage": 2, "reach": 2.3, "size": 1.15, "cooldown": 1.8, "armor": 1,
		"human": true, "roam": true, "parts": ["Barbarian_Hat"], "colors": [Color(0.5, 0.36, 0.28), Color(0.3, 0.26, 0.22), Color(0.4, 0.3, 0.22)]},
	# The chief is the boss of the pass (see BanditChief).
	"hauptmann": {"model": "Knight", "dir": "characters", "weapon": "sword_1handed", "shield": "shield_round", "hp": 20, "speed": 4.2, "damage": 2, "reach": 2.2, "size": 1.1, "cooldown": 1.4,
		"human": true, "roam": true, "parts": ["Knight_Cape"], "colors": [Color(0.45, 0.14, 0.12), Color(0.22, 0.2, 0.2), Color(0.5, 0.1, 0.1)]},
	# The beasts of the wild (Quaternius models in assets/wild): "beast"
	# kinds bite or claw instead of holding a weapon. "anims" maps the
	# animation names played here to the model's own, "model_scale" and
	# "turn" fit the model to the hero's size and facing, "run_anim" is the
	# ground speed (m/s) the run animation was made for, "voice" is a growl
	# (sound, pitch, comic word), "purse" the gold a fallen one leaves and
	# "gear_chance" how likely it carries a piece of gear.
	"wolf": {"model": "Wolf", "dir": "wild", "hp": 2, "speed": 6.2, "damage": 1, "reach": 2.0, "size": 1.0, "cooldown": 1.2,
		"beast": true, "roam": true, "model_scale": 0.65, "turn": 0.0, "run_anim": 6.0,
		"anims": {"Idle": "Idle", "Walking_A": "Walk", "Running_A": "Gallop", "1H_Melee_Attack_Chop": "Attack", "Hit_A": "Idle_HitReact1", "Death_A": "Death"},
		"voice": ["voice_koloss", 1.6, "knurr"], "purse": [0, 1], "gear_chance": 0.0},
	"ork": {"model": "Orc", "dir": "wild", "hp": 5, "speed": 4.0, "damage": 2, "reach": 2.2, "size": 1.1, "cooldown": 1.7, "armor": 1,
		"beast": true, "roam": true, "model_scale": 0.9, "turn": 0.0, "run_anim": 4.5,
		"anims": {"Idle": "Idle", "Walking_A": "Walk", "Running_A": "Run", "1H_Melee_Attack_Chop": "Punch", "Hit_A": "HitReact", "Death_A": "Death"},
		"voice": ["voice_krieger", 0.7, "grunz"], "purse": [2, 5], "gear_chance": 0.5},
	"yeti": {"model": "Yeti", "dir": "wild", "hp": 9, "speed": 3.6, "damage": 2, "reach": 2.6, "size": 1.4, "cooldown": 2.0, "armor": 1,
		"beast": true, "roam": true, "model_scale": 0.75, "turn": 0.0, "run_anim": 4.5,
		"anims": {"Idle": "Idle", "Walking_A": "Walk", "Running_A": "Run", "1H_Melee_Attack_Chop": "Punch", "Hit_A": "HitReact", "Death_A": "Death"},
		"voice": ["voice_koloss", 0.75, "BRÜLL"], "purse": [4, 8], "gear_chance": 0.4},
	# The spider's model has no flinch of its own: it hops back instead.
	"spinne": {"model": "Spider", "dir": "wild", "hp": 3, "speed": 5.0, "damage": 1, "reach": 2.0, "size": 1.0, "cooldown": 1.3,
		"beast": true, "roam": true, "model_scale": 0.6, "turn": 0.0, "run_anim": 3.0,
		"anims": {"Idle": "HumanArmature|Spider_Idle", "Walking_A": "HumanArmature|Spider_Walk", "Running_A": "HumanArmature|Spider_Walk",
			"1H_Melee_Attack_Chop": "HumanArmature|Spider_Attack", "Hit_A": "HumanArmature|Spider_Jump", "Death_A": "HumanArmature|Spider_Death"},
		"voice": ["voice_wicht", 1.4, "zisch"], "purse": [0, 2], "gear_chance": 0.0, "poison": 0.3},
	# The monsters of the dragon's lair (Quaternius Monster Pack in
	# assets/lair, FBX files: "ext"). Bats and the dragon only ever fly, so
	# every move plays their flying loop; "lift" raises the model off the
	# floor. The dragon spits fire from afar ("fire": orange orbs that
	# burn instead of curse); it is a boss with a fight of its own (see Dragon).
	"fledermaus": {"model": "Bat", "dir": "lair", "ext": "fbx", "hp": 1, "speed": 6.6, "damage": 1, "reach": 1.9, "size": 0.8, "cooldown": 1.0,
		"beast": true, "roam": true, "model_scale": 0.62, "turn": 0.0, "run_anim": 6.0, "lift": 1.0,
		"anims": {"Idle": "BatArmature|Bat_Flying", "Walking_A": "BatArmature|Bat_Flying", "Running_A": "BatArmature|Bat_Flying",
			"1H_Melee_Attack_Chop": "BatArmature|Bat_Attack", "Hit_A": "BatArmature|Bat_Hit", "Death_A": "BatArmature|Bat_Death"},
		"voice": ["voice_wicht", 1.9, "fiep"], "purse": [0, 1], "gear_chance": 0.0},
	"schleim": {"model": "Slime", "dir": "lair", "ext": "fbx", "hp": 4, "speed": 2.6, "damage": 1, "reach": 1.9, "size": 1.0, "cooldown": 1.8,
		"beast": true, "roam": true, "model_scale": 0.6, "turn": -PI * 0.5, "run_anim": 2.5,
		"anims": {"Idle": "Armature|Slime_Idle", "Walking_A": "Armature|Slime_Walk", "Running_A": "Armature|Slime_Walk",
			"1H_Melee_Attack_Chop": "Armature|Slime_Attack", "Hit_A": "Armature|Slime_Idle", "Death_A": "Armature|Slime_Death"},
		"voice": ["voice_koloss", 1.5, "blubb"], "purse": [1, 3], "gear_chance": 0.15, "poison": 0.35},
	"drache": {"model": "Dragon", "dir": "lair", "ext": "fbx", "hp": 36, "speed": 3.4, "damage": 2, "reach": 14.0, "size": 1.6, "cooldown": 2.2,
		"beast": true, "ranged": true, "fire": true, "model_scale": 0.6, "turn": 0.0, "run_anim": 4.0, "lift": 1.0,
		"anims": {"Idle": "DragonArmature|Dragon_Flying", "Walking_A": "DragonArmature|Dragon_Flying", "Running_A": "DragonArmature|Dragon_Flying",
			"1H_Melee_Attack_Chop": "DragonArmature|Dragon_Attack", "1H_Ranged_Shoot": "DragonArmature|Dragon_Attack2",
			"Hit_A": "DragonArmature|Dragon_Hit", "Death_A": "DragonArmature|Dragon_Death"},
		"voice": ["voice_koloss", 0.6, "BRÜLL"], "purse": [12, 18], "gear_chance": 0.8},
	# The horrors: rare, huge things nobody has a name for (see Horrors).
	# They lurk in the creepy holes of the wild and, very rarely, deep in the
	# dungeon. Each one is a beast model blown up far past its size and
	# darkened ("tint" multiplies its colours), with a sickly glow under it
	# ("glow"). They never roam, a stab in the back only hurts them three
	# times as hard, and nobody knows what they are until one has fallen.
	"hohle_mutter": {"model": "Spider", "dir": "wild", "hp": 26, "speed": 4.6, "damage": 2, "reach": 3.4, "size": 2.4, "cooldown": 1.5,
		"beast": true, "horror": true, "model_scale": 0.6, "turn": 0.0, "run_anim": 3.0,
		"anims": {"Idle": "HumanArmature|Spider_Idle", "Walking_A": "HumanArmature|Spider_Walk", "Running_A": "HumanArmature|Spider_Walk",
			"1H_Melee_Attack_Chop": "HumanArmature|Spider_Attack", "Hit_A": "HumanArmature|Spider_Jump", "Death_A": "HumanArmature|Spider_Death"},
		"tint": Color(0.42, 0.36, 0.48), "glow": Color(0.55, 0.9, 0.4),
		"voice": ["voice_wicht", 0.55, "tsss"], "purse": [25, 40], "gear_chance": 1.0, "poison": 0.6},
	"bleicher_waechter": {"model": "Yeti", "dir": "wild", "hp": 32, "speed": 3.9, "damage": 3, "reach": 3.6, "size": 2.1, "cooldown": 2.2,
		"beast": true, "horror": true, "model_scale": 0.75, "turn": 0.0, "run_anim": 4.5,
		"anims": {"Idle": "Idle", "Walking_A": "Walk", "Running_A": "Run", "1H_Melee_Attack_Chop": "Punch", "Hit_A": "HitReact", "Death_A": "Death"},
		"tint": Color(0.62, 0.66, 0.78), "glow": Color(0.5, 0.65, 1.0),
		"voice": ["voice_koloss", 0.45, "hhhh"], "purse": [30, 45], "gear_chance": 1.0},
	"schlund": {"model": "Slime", "dir": "lair", "ext": "fbx", "hp": 28, "speed": 3.0, "damage": 2, "reach": 3.4, "size": 2.6, "cooldown": 1.9,
		"beast": true, "horror": true, "model_scale": 0.6, "turn": -PI * 0.5, "run_anim": 2.5,
		"anims": {"Idle": "Armature|Slime_Idle", "Walking_A": "Armature|Slime_Walk", "Running_A": "Armature|Slime_Walk",
			"1H_Melee_Attack_Chop": "Armature|Slime_Attack", "Hit_A": "Armature|Slime_Idle", "Death_A": "Armature|Slime_Death"},
		"tint": Color(0.16, 0.12, 0.18), "glow": Color(0.9, 0.2, 0.25),
		"voice": ["voice_koloss", 0.38, "gluck"], "purse": [25, 40], "gear_chance": 1.0, "poison": 0.5},
	# The mountains far to the east (see Mountains): the road there, the
	# high valley and the three mines. They are meant for a hero who has
	# trained hard and wears the best gear (see Mines.BENCHMARK), so they hit
	# hard and take many blows, but each kind has one clear trick: the
	# troll's slow, heavy blows, the orc's armour, the wolves' numbers, the
	# archer's bolts from afar, the slimes' poison or burn.
	"eiswolf": {"model": "Wolf", "dir": "wild", "hp": 11, "speed": 7.0, "damage": 2, "reach": 2.0, "size": 1.05, "cooldown": 1.0,
		"beast": true, "roam": true, "mountain": true, "model_scale": 0.7, "turn": 0.0, "run_anim": 6.0,
		"anims": {"Idle": "Idle", "Walking_A": "Walk", "Running_A": "Gallop", "1H_Melee_Attack_Chop": "Attack", "Hit_A": "Idle_HitReact1", "Death_A": "Death"},
		"tint": Color(0.78, 0.86, 1.0),
		"voice": ["voice_koloss", 1.4, "knurr"], "purse": [1, 3], "gear_chance": 0.0},
	"bergork": {"model": "Orc", "dir": "wild", "hp": 17, "speed": 4.6, "damage": 3, "reach": 2.3, "size": 1.25, "cooldown": 1.4, "armor": 2,
		"beast": true, "roam": true, "mountain": true, "model_scale": 1.0, "turn": 0.0, "run_anim": 4.5,
		"anims": {"Idle": "Idle", "Walking_A": "Walk", "Running_A": "Run", "1H_Melee_Attack_Chop": "Punch", "Hit_A": "HitReact", "Death_A": "Death"},
		"tint": Color(0.62, 0.6, 0.72),
		"voice": ["voice_krieger", 0.6, "grunz"], "purse": [4, 9], "gear_chance": 0.6},
	"felstroll": {"model": "Yeti", "dir": "wild", "hp": 34, "speed": 3.4, "damage": 5, "reach": 3.0, "size": 1.8, "cooldown": 2.4, "armor": 3,
		"beast": true, "roam": true, "mountain": true, "big": true, "model_scale": 0.75, "turn": 0.0, "run_anim": 4.5,
		"anims": {"Idle": "Idle", "Walking_A": "Walk", "Running_A": "Run", "1H_Melee_Attack_Chop": "Punch", "Hit_A": "HitReact", "Death_A": "Death"},
		"tint": Color(0.5, 0.46, 0.42),
		"voice": ["voice_koloss", 0.55, "GRRUMM"], "purse": [8, 15], "gear_chance": 0.7},
	"klippenschuetze": {"model": "Rogue", "dir": "characters", "weapon": "Skeleton_Crossbow", "hp": 11, "speed": 4.2, "damage": 3, "reach": 24.0, "size": 1.0, "cooldown": 2.2, "armor": 1, "ranged": true,
		"human": true, "roam": true, "mountain": true, "parts": ["Rogue_Cape"], "colors": [Color(0.42, 0.44, 0.48), Color(0.3, 0.3, 0.32), Color(0.62, 0.64, 0.7)],
		"purse": [3, 7], "gear_chance": 0.5},
	"kristallschleim": {"model": "Slime", "dir": "lair", "ext": "fbx", "hp": 16, "speed": 3.0, "damage": 3, "reach": 2.1, "size": 1.3, "cooldown": 1.7, "armor": 2,
		"beast": true, "roam": true, "mountain": true, "model_scale": 0.75, "turn": -PI * 0.5, "run_anim": 2.5,
		"anims": {"Idle": "Armature|Slime_Idle", "Walking_A": "Armature|Slime_Walk", "Running_A": "Armature|Slime_Walk",
			"1H_Melee_Attack_Chop": "Armature|Slime_Attack", "Hit_A": "Armature|Slime_Idle", "Death_A": "Armature|Slime_Death"},
		"tint": Color(0.55, 0.85, 1.0), "glow": Color(0.4, 0.8, 1.0),
		"voice": ["voice_koloss", 1.3, "klirr"], "purse": [3, 7], "gear_chance": 0.25, "poison": 0.4},
	"glutschleim": {"model": "Slime", "dir": "lair", "ext": "fbx", "hp": 18, "speed": 3.2, "damage": 4, "reach": 2.1, "size": 1.3, "cooldown": 1.8, "armor": 1,
		"beast": true, "roam": true, "mountain": true, "model_scale": 0.75, "turn": -PI * 0.5, "run_anim": 2.5,
		"anims": {"Idle": "Armature|Slime_Idle", "Walking_A": "Armature|Slime_Walk", "Running_A": "Armature|Slime_Walk",
			"1H_Melee_Attack_Chop": "Armature|Slime_Attack", "Hit_A": "Armature|Slime_Idle", "Death_A": "Armature|Slime_Death"},
		"tint": Color(1.0, 0.45, 0.2), "glow": Color(1.0, 0.45, 0.15),
		"voice": ["voice_koloss", 1.1, "zisch"], "purse": [4, 8], "gear_chance": 0.25},
	# The boss deep down in the third mine (see Mines): a rock troll grown
	# huge on the mountain's heat. A plain fight, but a long one: big, slow
	# blows to step away from, and a health bar at the top.
	"bergkoenig": {"model": "Yeti", "dir": "wild", "hp": 150, "speed": 3.6, "damage": 9, "reach": 4.0, "size": 2.6, "cooldown": 2.6, "armor": 3,
		"beast": true, "mountain": true, "boss": true, "big": true, "model_scale": 0.75, "turn": 0.0, "run_anim": 4.5,
		"anims": {"Idle": "Idle", "Walking_A": "Walk", "Running_A": "Run", "1H_Melee_Attack_Chop": "Punch", "Hit_A": "HitReact", "Death_A": "Death"},
		"tint": Color(0.36, 0.28, 0.26), "glow": Color(1.0, 0.4, 0.12),
		"voice": ["voice_koloss", 0.4, "GRROOOM"], "purse": [60, 90], "gear_chance": 1.0},
	# The Great Old One's dungeon below the high valley (see ElderLair): the
	# brood drakes, young dragons that hover and spit fire from afar, and the
	# Great Old One itself, a dragon far too old and too big to be slain (see
	# ElderDragon). Its numbers do not matter: no blade gets through.
	"brutdrache": {"model": "Dragon", "dir": "lair", "ext": "fbx", "hp": 18, "speed": 4.4, "damage": 3, "reach": 16.0, "size": 1.15, "cooldown": 2.3, "armor": 1,
		"beast": true, "roam": true, "ranged": true, "fire": true, "model_scale": 0.42, "turn": 0.0, "run_anim": 4.0, "lift": 1.0,
		"anims": {"Idle": "DragonArmature|Dragon_Flying", "Walking_A": "DragonArmature|Dragon_Flying", "Running_A": "DragonArmature|Dragon_Flying",
			"1H_Melee_Attack_Chop": "DragonArmature|Dragon_Attack", "1H_Ranged_Shoot": "DragonArmature|Dragon_Attack2",
			"Hit_A": "DragonArmature|Dragon_Hit", "Death_A": "DragonArmature|Dragon_Death"},
		"tint": Color(0.5, 0.42, 0.62), "glow": Color(0.75, 0.35, 1.0),
		"voice": ["voice_koloss", 0.95, "fauch"], "purse": [5, 10], "gear_chance": 0.5},
	"grosser_alter": {"model": "Dragon", "dir": "lair", "ext": "fbx", "hp": 200, "speed": 0.0, "damage": 1, "reach": 30.0, "size": 3.6, "cooldown": 3.0, "armor": 9,
		"beast": true, "big": true, "model_scale": 0.6, "turn": 0.0, "run_anim": 4.0, "lift": 0.0,
		"anims": {"Idle": "DragonArmature|Dragon_Flying", "Walking_A": "DragonArmature|Dragon_Flying", "Running_A": "DragonArmature|Dragon_Flying",
			"1H_Melee_Attack_Chop": "DragonArmature|Dragon_Attack", "1H_Ranged_Shoot": "DragonArmature|Dragon_Attack2",
			"Hit_A": "DragonArmature|Dragon_Hit", "Death_A": "DragonArmature|Dragon_Death"},
		"tint": Color(0.62, 0.5, 0.66), "glow": Color(0.7, 0.3, 1.0),
		"voice": ["voice_koloss", 0.3, "BRÜLL"], "purse": [0, 0], "gear_chance": 0.0},
}
## Every horror there is (see Horrors).
const HORRORS := ["hohle_mutter", "bleicher_waechter", "schlund"]
## Which map letter places which kind.
const LETTERS := {"M": "krieger", "A": "schuetze", "Z": "magier", "w": "wicht", "G": "koloss", "W": "waechter",
	"v": "fledermaus", "s": "schleim", "R": "drache",
	"J": "felstroll", "O": "bergork", "e": "eiswolf", "i": "kristallschleim", "g": "glutschleim", "Y": "bergkoenig",
	"d": "brutdrache", "@": "grosser_alter"}
## The letters of the open-air map that place bandits (see Outdoor).
const WILD_LETTERS := {"c": "halsabschneider", "A": "wilderer", "X": "schlaeger", "Q": "hauptmann",
	"W": "wolf", "H": "ork", "J": "yeti", "U": "spinne",
	"{": "felstroll", "}": "bergork", "-": "eiswolf", "/": "klippenschuetze"}
## Body parts every adventurer model keeps; the rest shows only when a kind asks for it.
const BODY_PARTS := ["Body", "Head", "ArmLeft", "ArmRight", "LegLeft", "LegRight"]
## How far from home a roaming bandit wanders (tiles), and how far it will
## chase the hero (metres) before it gives up and strolls back.
const ROAM_TILES := 4
const LEASH_ROAM := 48.0
## How far a monster spots a rival (metres, needs a clear line of sight),
## how often it looks for one (seconds), and how far a befriended monster
## comes to the hero's aid.
const RIVAL_SIGHT := 14.0
const RIVAL_SCAN := 0.5
const HELP_RANGE := 16.0
## Seconds a gift keeps a monster calm, even if its kind is not won over yet.
const GIFT_CALM := 10.0
## A stab counts as from behind when it comes from outside this angle either
## side of where the skeleton looks.
const BEHIND := deg_to_rad(100.0)
## Depth scaling (see _ready): +1 life every HP_EVERY_LEVELS levels down and
## +1 damage every DAMAGE_EVERY_LEVELS, counted up to DEEPEST (the open wild
## lies past the dungeon and gets the full bonus).
const HP_EVERY_LEVELS := 3
const DAMAGE_EVERY_LEVELS := 4
const DEEPEST := 9

var level: Level
var kind := "krieger"
## A monster made in the map workshop (see Creations.monster_stats): numbers
## that replace those of its kind, and its own name ("title") over its head.
var custom := {}
## Elite skeletons have two more life, move and strike faster, and show it
## with dark bones and glowing red eyes.
var elite := false
## Out at night (see Outdoor): a bandit is bolder, with two more life and
## quicker blows; a skeleton risen from its grave roams the graveyard
## instead of standing guard.
var night := false
## A risen skeleton caught by the dawn sinks back into its grave as soon as
## it is off the hunt.
var _dawn := false
## Items the skeleton wears, from the same list as the hero's. Each one
## makes it stronger and may drop when it falls.
var gear: Array[String] = []
## Taken off every hit, like the hero's: the kind's own "armor" plus the
## "armor" of its worn gear. A hit still keeps at least half its force (see
## Player.soak), and a stab in the back goes through it.
var hardening := 0
var ranged := false
var hp := 3
var dead := false
var _stats: Dictionary
## The spot the skeleton takes up (see Level.push_apart).
var radius := 0.6
var tall := 2.4

var _model: Node3D
var _anim: AnimationPlayer
var _current_anim := ""
var _busy := 0.0
var _cooldown := 0.0
var _awake := false
## Seconds spent pushing without getting anywhere, and the sidestep out.
var _stuck := 0.0
## Seconds before spikes can hurt this skeleton again.
var _trap_cool := 0.0
var _detour := Vector3.ZERO
var _detour_time := 0.0
var _path: Array[Vector3] = []
var _repath := 0.0
var _knockback := Vector3.ZERO
## The post, taken where the skeleton stands on its first frame (the level
## places it only after it is ready).
var _home := Vector3.INF
## Where the hero was last noticed, and how long ago.
var _last_known := Vector3.ZERO
var _lost := 0.0
## A guard at rest looks around now and then.
var _look_angle := 0.0
var _look_timer := 0.0
## Where a guardian keeps looking while at its post.
var _watch := Vector3.INF
var _step_timer := 0.0
## How far the hero hears a skeleton walking in the dark.
const HEARD_FROM := 16.0
## Every kind has a voice of its own (voice_<kind>_0 and _1), so the hero
## can tell what lurks nearby. Out of sight, a word shows where it came from.
const VOICE_RANGE := 18.0
const VOICE_WORDS := {"krieger": "knurr", "schuetze": "zisch", "magier": "murmel",
	"wicht": "kicher", "koloss": "GROLL", "waechter": "klirr"}
## What a bandit shouts while it hunts the hero.
const TAUNTS := ["Her mit dem Gold!", "Den schnappen wir uns!", "Dein Beutel oder dein Leben!", "Keiner kommt hier durch!"]
var _voice_timer := 0.0
## Where a roaming bandit is strolling to, and how long it lingers there.
var _roam_pause := 0.0
## The rival this one is fighting (see Factions): another monster, not the hero.
var foe: Enemy = null
## Seconds until it looks around for rivals again.
var _scan := 0.0
## Seconds a gift still keeps it calm (see calm).
var _calmed := 0.0
## Whether the blow that felled it came from another monster rather than
## the hero: such a kill counts for no task.
var slain_by_rival := false
## The hero level this one is a fair fight for (see HeroLevel), set when it
## is ready; what felling it is worth goes by it.
var rated_level := 1


## Balances a monster to the area it lives in (see HeroLevel.AREAS): a
## weaker one gets more life first and, every other step, a harder blow until
## it is a fair fight for its place in the area's levels; a stronger one than
## the area's top loses blow strength first, then life. Then notes the level
## it is rated at.
func _fit_area() -> void:
	rated_level = _rating()
	var area := HeroLevel.area_of(level, kind) if level else ""
	if area == "" or HeroLevel.FIXED.has(kind):
		return
	rated_level = fit_level(kind, _stats, hardening, HeroLevel.area_target(area, rated_level), HeroLevel.AREAS[area].max)


func _rating() -> int:
	return HeroLevel.rate(kind, int(_stats.hp), int(_stats.damage), hardening, float(_stats.cooldown))


## Lifts a monster's numbers ("hp", "damage" in `stats`, changed in place)
## until it rates at least `target`, then tones them down to at most `top`
## (see _fit_area). Returns the level it rates at in the end.
static func fit_level(kind_id: String, stats: Dictionary, armour: int, target: int, top: int) -> int:
	var rate := func() -> int:
		return HeroLevel.rate(kind_id, int(stats.hp), int(stats.damage), armour, float(stats.cooldown))
	var rated: int = rate.call()
	var step := 0
	while rated < target and step < 80:
		if step % 2 == 0:
			stats.hp = int(stats.hp) + maxi(1, int(stats.hp) / 8)
		else:
			stats.damage = int(stats.damage) + 1
		step += 1
		rated = rate.call()
	step = 0
	while rated > top and step < 80:
		if step % 2 == 0 and int(stats.damage) > 1:
			stats.damage = int(stats.damage) - 1
		elif int(stats.hp) > 1:
			stats.hp = int(stats.hp) - maxi(1, int(stats.hp) / 10)
		step += 1
		rated = rate.call()
	return rated


## The yardstick for the hero's odds on the character page: a plain bandit
## of the pass, a person who fights with a blade.
const REFERENCE_KIND := "halsabschneider"


## What a REFERENCE_KIND (no gear, by day) has when it is balanced to be a
## fair fight for a hero of `hero_level`: "hp", "damage", "armor", "level".
static func reference_foe(hero_level: int) -> Dictionary:
	var stats: Dictionary = KINDS[REFERENCE_KIND].duplicate()
	var armour: int = stats.get("armor", 0)
	var rated := fit_level(REFERENCE_KIND, stats, armour, hero_level, hero_level)
	return {"hp": int(stats.hp), "damage": int(stats.damage), "armor": armour, "level": rated}


## The name of a monster made in the map workshop, over its head in red.
func _add_title(text: String, size: float) -> void:
	var tag := Label3D.new()
	tag.text = text
	tag.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tag.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	tag.font_size = 30
	tag.pixel_size = 0.011
	tag.outline_size = 10
	tag.outline_modulate = Color(0.05, 0.03, 0.06, 0.85)
	tag.modulate = Color(1.0, 0.55, 0.45)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.render_priority = 18
	tag.outline_render_priority = 17
	tag.position.y = tall + 0.5
	add_child(tag)


## Whether felling this one is a boss's worth of experience.
func is_level_boss() -> bool:
	return kind in HeroLevel.BOSSES


func _ready() -> void:
	SmoothMotion.follow_ticks(self)
	_stats = KINDS[kind].duplicate()
	_stats.merge(custom, true)
	_scan = randf() * RIVAL_SCAN
	if elite:
		_stats.hp += 2
		_stats.speed *= 1.15
		_stats.cooldown *= 0.8
		if not _stats.has("tint"):
			_stats.tint = Color(0.42, 0.38, 0.46)
	if night and is_human():
		_stats.hp += 2
		_stats.cooldown *= 0.85
		_stats.speed *= 1.08
	elif night:
		_stats.roam = true
	# Deeper down the dead are tougher and hit harder. The bosses keep their
	# own numbers.
	if level and kind not in ["drache", "hauptmann", "bergkoenig", "grosser_alter"]:
		var deep := clampi(level.depth, 0, DEEPEST)
		_stats.hp += deep / HP_EVERY_LEVELS
		_stats.damage += deep / DAMAGE_EVERY_LEVELS
	hardening = _stats.get("armor", 0)
	var power := 0
	var gear_weight := 0.0
	for id in gear:
		var item: Dictionary = Items.ALL[id]
		_stats.hp += item.get("hp", 0)
		hardening += item.get("armor", 0)
		power += item.get("power", 0)
		_stats.speed *= 1.0 + item.get("speed", 0.0)
		gear_weight += Items.weight(id)
	# Skeletons carry their gear's weight just like the hero.
	_stats.speed *= Items.load_factor(gear_weight)
	# Strength makes blows come faster and, every two points, harder too.
	_stats.cooldown /= 1.0 + 0.2 * power
	_stats.damage += power / 2
	_fit_area()
	ranged = _stats.get("ranged", false)
	hp = _stats.hp
	add_to_group("combatant")
	var size: float = _stats.size
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	# The colossus is a touch slimmer than it looks, so it fits through doors.
	radius = 0.6 * minf(size, 1.25)
	tall = 2.4 * size
	capsule.radius = radius
	capsule.height = tall
	shape.shape = capsule
	shape.position.y = 1.2 * size
	add_child(shape)

	var body: Node3D = load("res://assets/%s/%s.%s" % [_stats.get("dir", "enemies"), _stats.model, _stats.get("ext", "glb")]).instantiate()
	if is_beast():
		# A pivot turns and scales the beast's model to fit; the class only
		# ever turns the pivot.
		_model = Node3D.new()
		_model.add_child(body)
		body.rotation.y = _stats.turn
		body.scale = Vector3.ONE * _stats.model_scale
		body.position.y = _stats.get("lift", 0.0)
	else:
		_model = body
	add_child(_model)
	_model.rotation.y = PI
	_model.scale = Vector3.ONE * size
	if _stats.has("title"):
		_add_title(str(_stats.title), size)
	if is_human():
		_dress()
	if is_beast():
		_ready_beast()
		return
	var skeleton: Skeleton3D = _model.find_child("Skeleton3D", true, false)
	var weapon := _worn("waffe")
	if weapon.has("model") and not ranged:
		_hold(skeleton, "handslot.r", weapon.model)
	else:
		_hold(skeleton, "handslot.r", "res://assets/weapons/%s.gltf" % _stats.weapon)
	var shield := _worn("schild")
	if _stats.has("shield"):
		_hold(skeleton, "handslot.l", "res://assets/weapons/%s.gltf" % _stats.shield)
	elif shield.has("model"):
		_hold(skeleton, "handslot.l", shield.model)
	if _stats.has("tint"):
		for mesh in _model.find_children("*", "MeshInstance3D", true, false):
			if not mesh.name.ends_with("_Eyes"):
				_tint(mesh, _stats.tint)
	# Worn cloaks and armour colour the skeleton like they colour the hero.
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		var part := "umhang" if mesh.name.ends_with("_Cloak") or mesh.name.ends_with("_Cape") else "ruestung" if mesh.name.ends_with("_Body") else ""
		if part != "" and _worn(part).has("tint"):
			_tint(mesh, _worn(part).tint, _worn(part).get("metal", 0.0))
	if elite or kind == "koloss" or kind == "waechter":
		_glowing_eyes()
	_anim = _model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Running_A", "Walking_A", "Walking_D_Skeletons", "Skeleton_Inactive_Standing_Pose"]:
		if _anim.has_animation(a):
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")
	_cooldown = randf_range(0.5, 1.5)
	_look_angle = randf() * TAU
	_model.rotation.y = _look_angle
	_look_timer = randf_range(2.0, 5.0)
	_voice_timer = randf_range(2.0, 10.0)


## How much wider than a normal skeleton this one is, so blades reach it.
func girth() -> float:
	return 0.6 * (float(_stats.size) - 1.0)


## Whether this is a person (a bandit) rather than a skeleton.
func is_human() -> bool:
	return _stats.get("human", false)


## Whether this is an animal or monster of the wild.
func is_beast() -> bool:
	return _stats.get("beast", false)


## Whether this is one of the nameless horrors (see Horrors).
func is_horror() -> bool:
	return _stats.get("horror", false)


## Its full life, gear included.
func max_hp() -> int:
	return int(_stats.hp)


## Whether this one's faction is the hero's friend (see Factions).
func is_friend() -> bool:
	return Factions.is_friendly(Factions.of(kind))


## A gift calms it: it stops hunting the hero for a while.
func calm() -> void:
	_calmed = GIFT_CALM
	_awake = false
	_path.clear()
	_repath = 0.0


## What the message line says when this one falls.
func fall_text() -> String:
	match kind:
		"wolf":
			return Lang.t("Der Wolf bleibt liegen.")
		"ork":
			return Lang.t("Der Ork geht zu Boden.")
		"yeti":
			return Lang.t("Der Yeti stürzt um.")
		"spinne":
			return Lang.t("Die Spinne rollt sich zusammen.")
		"fledermaus":
			return Lang.t("Die Fledermaus fällt zu Boden.")
		"schleim":
			return Lang.t("Der Schleim zerfließt.")
		"drache":
			return Lang.t("Der Drache stürzt brüllend zu Boden!")
		"fog_wraith":
			return Lang.t("Der Nebelgeist verweht.")
		"eiswolf":
			return Lang.t("Der Eiswolf bleibt liegen.")
		"bergork":
			return Lang.t("Der Bergork kracht zu Boden.")
		"felstroll":
			return Lang.t("Der Felstroll stürzt wie ein Felsbrocken um.")
		"klippenschuetze":
			return Lang.t("Der Klippenschütze fällt.")
		"kristallschleim", "glutschleim":
			return Lang.t("Der Schleim zerfließt.")
		"bergkoenig":
			return Lang.t("Der Bergkönig stürzt! Der ganze Berg erbebt.")
		"brutdrache":
			return Lang.t("Der Brutdrache stürzt zu Boden.")
	if is_horror():
		return Lang.t("Das Ungeheuer bricht zusammen. Die Stille danach ist fast schlimmer.")
	return Lang.t("Der Räuber geht zu Boden.") if is_human() else Lang.t("Das Skelett zerfällt zu Staub.")


## The rest of _ready for a beast: no weapon, its own animations. A tinted
## kind is darkened, a glowing one glows from below, and the slimes are
## made of murky water (see _slime).
func _ready_beast() -> void:
	_anim = _model.find_child("AnimationPlayer", true, false)
	if _stats.model == "Slime":
		_slime()
	elif _stats.has("tint"):
		_darken(_stats.tint)
	if _stats.has("glow"):
		var glow := OmniLight3D.new()
		glow.light_color = _stats.glow
		glow.light_energy = 1.4
		glow.omni_range = 2.2 * float(_stats.size)
		glow.position = Vector3(0, 0.6 * float(_stats.size), 0.4 * float(_stats.size))
		add_child(glow)
	var anims: Dictionary = _stats.anims
	for a in ["Idle", "Walking_A", "Running_A"]:
		if _anim.has_animation(anims[a]):
			_anim.get_animation(anims[a]).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")
	_cooldown = randf_range(0.5, 1.5)
	_look_angle = randf() * TAU
	_model.rotation.y = _look_angle
	_look_timer = randf_range(2.0, 5.0)
	_voice_timer = randf_range(2.0, 10.0)


## Bandits keep only their body and the parts their kind asks for, and
## wear clothes in their kind's colours (body, legs, hat or cape). A worn
## cloak from the gear shows as the model's own cape.
func _dress() -> void:
	var parts: Array = _stats.get("parts", [])
	var colors: Array = _stats.get("colors", [])
	if _worn("umhang").has("tint"):
		for mi: MeshInstance3D in _model.find_children("*_Cape", "MeshInstance3D", true, false):
			parts = parts + [String(mi.name)]
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		var part := String(mi.name)
		var base := ""
		for b in BODY_PARTS:
			if part.ends_with("_" + b):
				base = b
		if base == "" and not part in parts:
			mi.visible = false
			continue
		var color := Color.WHITE
		if base == "Body":
			color = colors[0]
		elif base.begins_with("Leg"):
			color = colors[1]
		elif base.begins_with("Arm"):
			color = Color.WHITE.lerp(colors[0], 0.5)
		elif base == "":
			color = colors[2]
		if color != Color.WHITE:
			var mat := mi.get_active_material(0)
			if mat is StandardMaterial3D:
				var dyed: StandardMaterial3D = mat.duplicate()
				dyed.albedo_color = color
				mi.material_override = dyed


## The worn item for a slot, or an empty one.
func _worn(slot: String) -> Dictionary:
	for id in gear:
		if Items.ALL[id].slot == slot:
			return Items.ALL[id]
	return {}


func _hold(skeleton: Skeleton3D, bone: String, model: String) -> void:
	var hand := BoneAttachment3D.new()
	hand.bone_name = bone
	skeleton.add_child(hand)
	hand.add_child(load(model).instantiate())


const TINT_SHADER := preload("res://shaders/tint.gdshader")


## Recolours bones (brutes, elites) or worn cloaks and armour.
func _tint(mesh: MeshInstance3D, color: Color, metal := 0.0) -> void:
	var source := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	if source == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = TINT_SHADER
	mat.set_shader_parameter("tex", source.albedo_texture)
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("metal", metal)
	mesh.material_override = mat


## Multiplies every colour of a beast's model by `color`. Beast models come
## with plain materials of their own, so each one is copied and darkened.
func _darken(color: Color) -> void:
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(i) as BaseMaterial3D
			if source == null:
				continue
			var mat := source.duplicate() as BaseMaterial3D
			mat.albedo_color = source.albedo_color * color
			mesh.set_surface_override_material(i, mat)


const SLIME_SHADER := preload("res://shaders/slime.gdshader")
## The murky, greenish water of the dungeon's neglected fountain, which the
## plain slimes are made of: deep, shallow and scum colours.
const SLIME_MURK := [Color(0.07, 0.12, 0.07), Color(0.27, 0.36, 0.18), Color(0.24, 0.26, 0.1)]
## The slimes' body with its eyes left off and smoothed, shared by all slimes.
static var _slime_body: ArrayMesh


## The slimes are lumps of murky water without eyes: a glossy, see-through
## body that wobbles and drips (see slime.gdshader). A kind with a tint is
## water of that colour, still a little dirty.
func _slime() -> void:
	var meshes := _model.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	var mesh: MeshInstance3D = meshes[0]
	if _slime_body == null:
		_slime_body = _smooth_body(mesh.mesh)
	mesh.mesh = _slime_body
	var mat := ShaderMaterial.new()
	mat.shader = SLIME_SHADER
	var murk: Array = SLIME_MURK
	if _stats.has("tint"):
		var tint: Color = _stats.tint
		var dirt: Color = SLIME_MURK[1]
		murk = [tint.lerp(dirt, 0.3).darkened(0.75), tint.lerp(dirt, 0.25).darkened(0.4), tint.lerp(SLIME_MURK[2], 0.6).darkened(0.3)]
	mat.set_shader_parameter("deep_color", murk[0])
	mat.set_shader_parameter("shallow_color", murk[1])
	mat.set_shader_parameter("scum_color", murk[2])
	if _stats.has("glow"):
		mat.set_shader_parameter("glow_color", _stats.glow)
		mat.set_shader_parameter("glow", 0.35)
	var box := mesh.global_transform * _slime_body.get_aabb()
	mat.set_shader_parameter("height", box.size.y)
	mat.set_shader_parameter("phase", randf() * 100.0)
	mesh.material_override = mat
	# Both sit in the model, so they shrink and spread with it as it melts.
	_slime_puddle(murk[1], box.size / _model.scale.x)
	_slime_drops(murk[1], box.size / _model.scale.x)


## A wet, glossy smear under the slime that goes where it goes.
func _slime_puddle(color: Color, body: Vector3) -> void:
	var fade := GradientTexture2D.new()
	fade.fill = GradientTexture2D.FILL_RADIAL
	fade.fill_from = Vector2(0.5, 0.5)
	fade.fill_to = Vector2(0.5, 0.0)
	fade.gradient = Gradient.new()
	fade.gradient.set_color(0, Color(1, 1, 1, 0.8))
	fade.gradient.set_color(1, Color(1, 1, 1, 0.0))
	fade.gradient.add_point(0.7, Color(1, 1, 1, 0.6))
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.albedo_texture = fade
	mat.roughness = 0.06
	mat.metallic_specular = 0.8
	var plane := PlaneMesh.new()
	plane.size = Vector2(body.x, body.z) * 1.25
	var puddle := MeshInstance3D.new()
	puddle.mesh = plane
	puddle.material_override = mat
	puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puddle.position.y = 0.04 / _model.scale.x
	_model.add_child(puddle)


## Now and then a drop of slime runs off its sides and falls to the floor.
func _slime_drops(color: Color, body: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color, 0.85)
	mat.roughness = 0.05
	mat.metallic_specular = 0.8
	var drop := SphereMesh.new()
	drop.radius = 0.045 * body.y
	drop.height = 0.16 * body.y
	drop.radial_segments = 8
	drop.rings = 4
	drop.material = mat
	var drops := CPUParticles3D.new()
	drops.mesh = drop
	drops.amount = 6
	drops.lifetime = 0.9
	drops.randomness = 0.6
	drops.local_coords = false
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	drops.emission_ring_axis = Vector3.UP
	drops.emission_ring_radius = 0.42 * minf(body.x, body.z)
	drops.emission_ring_inner_radius = 0.3 * minf(body.x, body.z)
	drops.emission_ring_height = 0.0
	drops.direction = Vector3.DOWN
	drops.spread = 5.0
	drops.initial_velocity_min = 0.0
	drops.initial_velocity_max = 0.3
	drops.gravity = Vector3(0, -4.0, 0)
	drops.scale_amount_min = 0.6
	drops.scale_amount_max = 1.2
	drops.position.y = 0.35 * body.y
	_model.add_child(drops)


## The body of the slime model alone, without the eyes (its second surface),
## with its facets smoothed away so it shines like something wet.
static func _smooth_body(source: Mesh) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	# Every corner at one spot gets the mean of the facets meeting there.
	var sums := {}
	for i in verts.size():
		var key := verts[i].snappedf(0.00001)
		sums[key] = sums.get(key, Vector3.ZERO) + normals[i]
	for i in verts.size():
		normals[i] = (sums[verts[i].snappedf(0.00001)] as Vector3).normalized()
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var body := ArrayMesh.new()
	body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, source.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	body.surface_set_material(0, source.surface_get_material(0))
	return body


func _glowing_eyes() -> void:
	var eyes := _model.find_child("*_Eyes", true, false) as MeshInstance3D
	if eyes == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.05)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.15, 0.05)
	mat.emission_energy_multiplier = 4.0
	eyes.material_override = mat
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.2, 0.1)
	glow.light_energy = 0.5
	glow.omni_range = 1.2
	glow.position = Vector3(0, 2.0 * _stats.size, 0.6 * _stats.size)
	add_child(glow)


## `anim_name` is one of the skeleton models' animation names; a beast plays
## its own animation for it (see "anims" in KINDS).
func _play(anim_name: String, blend := 0.2) -> void:
	if _current_anim == anim_name:
		return
	_current_anim = anim_name
	_anim.play(_stats.get("anims", {}).get(anim_name, anim_name), blend)


func _play_once(anim_name: String, duration: float) -> void:
	_current_anim = ""
	_play(anim_name, 0.1)
	_busy = duration


## Has the guardian look at a spot (what it guards) while at its post.
func watch(at: Vector3) -> void:
	_watch = at
	var dir := at - global_position
	_look_angle = atan2(dir.x, dir.z)
	_model.rotation.y = _look_angle


## Which way the skeleton looks.
func ahead() -> Vector3:
	return Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))


## Whether a blade from `from` would be a stab in the back: from behind,
## and the skeleton has not noticed the hero.
func open_to_backstab(from: Vector3) -> bool:
	var to := from - global_position
	to.y = 0.0
	return not _awake and not dead and ahead().angle_to(to) > BEHIND


## Kind is "hit" for a blade, "knife" for a thrown knife, "backstab" for a
## stab in the back or "thorns" for the hero's thorn rune; it picks the comic
## word. Hardening softens every hit but a stab in the back, and swallows
## thorns whole. "pierce" is a plain hit that goes through the hardening
## (a boss caught off guard, see BanditChief).
func take_hit(damage: int, from: Vector3, kind := "hit", wakes := true) -> void:
	if dead:
		return
	if kind == "thorns":
		damage -= hardening
		if damage <= 0 or _stats.get("armored", false):
			return
		kind = "hit"
	elif kind == "pierce":
		kind = "hit"
	elif kind != "backstab":
		damage = Player.soak(damage, hardening)
	if kind == "backstab":
		# A horror, a rock troll or a boss is too big to fall to one stab:
		# it only hurts more.
		damage = damage * 3 if is_horror() or _stats.get("big", false) else hp
	elif _stats.get("armored", false):
		# Blades glance off the guardian's armour, and it turns to fight.
		if wakes:
			_wake(from)
		Effects.head_text(level, self, 2.2 * _stats.size, Lang.t("Nur ein Stich in den Rücken!"), Color(0.8, 0.85, 0.95))
		Comic.pop(global_position, "block")
		return
	hp -= damage
	if wakes:
		_calmed = 0.0
		_wake(from)
	var away := global_position - from
	away.y = 0.0
	_knockback = away.normalized() * 9.0 / (_stats.size * _stats.size)
	Effects.head_text(level, self, 2.2 * _stats.size, "-%d" % damage, Color(1, 0.45, 0.35))
	# The comic word below makes the sound of the blow.
	if hp <= 0:
		if is_human() or is_beast():
			# No bones to rattle: a person or a beast goes down with a thud.
			Comic.pop(global_position, "backstab" if kind == "backstab" else "big")
			Sfx.play(self, "hit", -2.0, global_position)
		else:
			Comic.pop(global_position, "backstab" if kind == "backstab" else "break")
			Sfx.play(self, "bones", 0.0, global_position)
		_die()
	else:
		Comic.pop(global_position, "big" if damage >= 2 else kind)
		_play_once("Hit_A", 0.45)


## How long a lightning crack from a thunder weapon stuns (see shock).
const SHOCK_TIME := 1.5
const SHOCK_COLOR := Color(0.55, 0.8, 1.0)


## Whether a thunder weapon's crack can stun it: a horror, a big brute or a
## boss shrugs it off.
func can_be_stunned() -> bool:
	return not dead and not is_horror() and not _stats.get("big", false) and not _stats.get("armored", false)


## A thunder weapon's blow cracked with lightning (see Player.melee): it
## stands stunned for SHOCK_TIME, neither moving nor striking, with blue
## sparks and a word over its head. Returns whether it was stunned.
func shock() -> bool:
	if not can_be_stunned():
		return false
	_play_once("Hit_A", SHOCK_TIME)
	Effects.head_text(level, self, 2.7 * _stats.size, Lang.t("Betäubt!"), SHOCK_COLOR)
	var sparks := Effects.make_sparkles(SHOCK_COLOR, true)
	sparks.position = Vector3(0, 1.4 * _stats.size, 0)
	add_child(sparks)
	Sfx.play(self, "thunder", -12.0, global_position, 2.2)
	return true


## A blow (or a shot) from a rival monster. It fights back; armour that
## stops the hero's blade stops a rival's just as well.
func hit_by_rival(damage: int, attacker: Enemy) -> void:
	if dead:
		return
	if attacker != null and is_instance_valid(attacker) and not attacker.dead:
		provoke(attacker)
	if _stats.get("armored", false):
		Comic.pop(global_position, "block")
		return
	var from: Vector3 = attacker.global_position if attacker != null and is_instance_valid(attacker) else global_position
	slain_by_rival = true
	take_hit(damage, from, "hit", false)
	if not dead:
		slain_by_rival = false


## Attacked by a rival: it turns on the attacker, unless it is busy with
## another rival already.
func provoke(attacker: Enemy) -> void:
	if attacker == self or dead:
		return
	if foe == null or not is_instance_valid(foe) or foe.dead:
		_set_foe(attacker)


func _set_foe(e: Enemy) -> void:
	if foe == e:
		return
	foe = e
	_path.clear()
	_repath = 0.0


## Spikes hurt skeletons too, once per thrust.
func hurt_by_trap(at: Vector3) -> void:
	if _trap_cool > 0.0 or dead or _stats.get("armored", false):
		return
	_trap_cool = 1.2
	take_hit(1, at, "hit", false)


## Waits at the edge of a spike trap that is up or about to strike, rather
## than walk into it. Already standing on one, it keeps going to get off.
func _mind_spikes(move: Vector3) -> Vector3:
	if move == Vector3.ZERO:
		return move
	var here := level.world_to_cell(global_position)
	var ahead := level.world_to_cell(global_position + move * Level.TILE * 0.45)
	if ahead != here and not level.is_spike_cell(here) and level.spike_danger(ahead):
		return Vector3.ZERO
	return move


## Dawn has come: back into the grave, now or once the hunt is over.
func sink_at_dawn() -> void:
	_dawn = true


## Sinks into the earth and is gone: no fall, no loot.
func _sink() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	_play("Idle")
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position:y", -2.8, 2.2)
	tween.tween_callback(queue_free)


func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	_play_once("Death_A", 99.0)
	if _stats.get("lift", 0.0) > 0.0:
		# A flyer drops out of the air.
		create_tween().tween_property(_model.get_child(0), "position:y", 0.0, 0.5) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	died.emit()
	# The body stays where it fell and rots away (see Corpse).
	Corpse.lay(self)


func _physics_process(delta: float) -> void:
	if dead or level == null or level.player == null:
		return
	if _dawn and not _awake:
		_sink()
		return
	if _home == Vector3.INF:
		_home = global_position
	_busy = maxf(0.0, _busy - delta)
	_trap_cool = maxf(0.0, _trap_cool - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	_repath -= delta
	var player: Player = level.player
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var sees := dist < SIGHT and level.has_line_of_sight(global_position, player.global_position)
	# Under the open sky there is no fog of war: everything shows.
	visible = level.fog == null or level.fog.is_cell_visible(level.world_to_cell(global_position))
	var friendly := is_friend()
	_calmed = maxf(0.0, _calmed - delta)
	if (friendly or _calmed > 0.0) and _awake:
		# A friend, or one just calmed by a gift, lets the hero be.
		_awake = false
		_path.clear()
		_repath = 0.0
	if not player.dead and not friendly and _calmed <= 0.0 and _notices(player, to_player, dist, sees):
		if not _awake:
			Effects.float_text(level, global_position + Vector3(0, 3.4 * _stats.size, 0), "!", Color(1.0, 0.3, 0.2))
		_wake(player.global_position)
	elif _awake:
		_lost += delta
		if _lost > GIVE_UP or player.dead:
			_awake = false
			_path.clear()
			_repath = 0.0
	var leash := LEASH if _watch != Vector3.INF else LEASH_ROAM if _stats.get("roam", false) else INF
	if _awake and _home != Vector3.INF and global_position.distance_to(_home) > leash:
		_awake = false
		_path.clear()
		_repath = 0.0
	_scan -= delta
	if _scan <= 0.0:
		_scan = RIVAL_SCAN
		_look_for_foe(friendly, leash)
	if foe != null and (not is_instance_valid(foe) or foe.dead):
		foe = null
		_path.clear()
		_repath = 0.0
	# A rival nearer than the hero is fought first.
	var fights_foe := foe != null and (not _awake or player.dead or _flat_distance(foe) < dist)

	var move := _step_out() if _busy <= 0.0 else Vector3.ZERO
	if move != Vector3.ZERO:
		pass # Out of the furniture first.
	elif fights_foe:
		if _busy <= 0.0:
			move = _fight_foe()
	elif _awake and not player.dead and _busy <= 0.0:
		if level.stacked(self, player):
			pass # Inside the hero's spot: no blow or shot until pushed apart.
		# With a pillar in the way an archer or mage walks round it first.
		elif ranged and sees and _lost <= 0.0 and dist < _stats.reach \
				and level.has_clear_shot(global_position, player.global_position):
			_face(to_player)
			if _cooldown <= 0.0:
				_shoot(player)
		elif not ranged and dist < _stats.reach and not level.door_between(global_position, player.global_position):
			_face(to_player)
			if _cooldown <= 0.0:
				_strike(player)
		else:
			if _repath <= 0.0 or _path.is_empty():
				_repath = 0.5
				_path.clear()
				for c in level.grid_path(level.world_to_cell(global_position), level.world_to_cell(_last_known)).slice(1):
					_path.append(level.cell_to_world(c))
				if _lost <= 0.0 and sees and _path.size() <= 1:
					_path.clear()
					_path.append(player.global_position)
			if not _path.is_empty():
				var to := _path[0] - global_position
				to.y = 0.0
				if to.length() < 0.4:
					_path.remove_at(0)
				else:
					move = to.normalized()
			elif _lost > 0.0:
				_look_around(delta)
	elif not _awake and not dead:
		move = _roam(delta) if _stats.get("roam", false) else _rest(delta)
	if _detour_time > 0.0 and move != Vector3.ZERO:
		_detour_time -= delta
		move = (move * 0.3 + _detour).normalized()
	move = _mind_spikes(move)
	velocity = move * float(_stats.speed) + _knockback
	velocity.y = -9.0
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 40.0)
	move_and_slide()
	if move != Vector3.ZERO:
		_face(move, delta)
	_check_stuck(delta, move)
	if _busy > 0.0:
		return
	# Off the hunt, a bandit strolls; skeletons shuffle back to their post.
	var strolling: bool = move != Vector3.ZERO and move.length() < 0.7 and (is_human() or _stats.get("roam", false))
	var walk: String = "Walking_D_Skeletons" if not is_human() and _anim.has_animation("Walking_D_Skeletons") else "Walking_A"
	_play(walk if strolling else "Running_A" if move != Vector3.ZERO else "Idle")
	_footfalls(delta, move != Vector3.ZERO, dist)
	_voice(delta, dist)
	# Feet keep pace with the ground; bigger skeletons take longer strides.
	var ground_speed := SmoothMotion.ground_speed(self)
	var run_anim: float = _stats.get("run_anim", Player.RUN_ANIM_SPEED)
	_anim.speed_scale = clampf(ground_speed / (run_anim * float(_stats.size)), 0.5, 2.5) if _current_anim == "Running_A" else 1.0


func _flat_distance(other: Node3D) -> float:
	return Vector2(other.global_position.x - global_position.x, other.global_position.z - global_position.z).length()


## Keeps up the fight with a rival while it is in reach, or finds a new one:
## the nearest rival in sight, and for a friend of the hero also any monster
## that hunts the hero nearby.
func _look_for_foe(friendly: bool, leash: float) -> void:
	if foe != null and (not is_instance_valid(foe) or foe.dead or _flat_distance(foe) > RIVAL_SIGHT * 1.5 \
			or (_home != Vector3.INF and global_position.distance_to(_home) > leash)):
		foe = null
		_path.clear()
		_repath = 0.0
	if foe != null:
		return
	var best: Enemy = null
	var best_d := HELP_RANGE if friendly else RIVAL_SIGHT
	for e in level.enemies:
		if not is_instance_valid(e) or e == self or e.dead:
			continue
		var d := _flat_distance(e)
		# A friend of the hero leaves the hero's other friends alone.
		if d >= best_d or (friendly and e.is_friend()):
			continue
		var rival: bool = d < RIVAL_SIGHT and Factions.kinds_are_rivals(kind, e.kind)
		var helps: bool = friendly and e.is_hunting()
		if (rival or helps) and level.has_line_of_sight(global_position, e.global_position):
			best = e
			best_d = d
	if best != null:
		_set_foe(best)


## Goes for the rival: a blow or a shot once it is in reach, else closer.
func _fight_foe() -> Vector3:
	var to := foe.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if level.stacked(self, foe):
		return Vector3.ZERO
	if ranged:
		if d < float(_stats.reach) and level.has_clear_shot(global_position, foe.global_position):
			_face(to)
			if _cooldown <= 0.0:
				_shoot(foe)
			return Vector3.ZERO
	elif d < float(_stats.reach) + foe.girth():
		_face(to)
		if _cooldown <= 0.0:
			_strike(foe)
		return Vector3.ZERO
	if _repath <= 0.0 or _path.is_empty():
		_repath = 0.5
		_path.clear()
		if level.has_line_of_sight(global_position, foe.global_position):
			_path.append(foe.global_position)
		else:
			for c in level.grid_path(level.world_to_cell(global_position), level.world_to_cell(foe.global_position)).slice(1):
				_path.append(level.cell_to_world(c))
	if _path.is_empty():
		return Vector3.ZERO
	var step := _path[0] - global_position
	step.y = 0.0
	if step.length() < 0.4:
		_path.remove_at(0)
		return Vector3.ZERO
	return step.normalized()


## A skeleton hidden in the dark can still be heard: footsteps and a faint
## mark where they sound.
func _footfalls(delta: float, moving: bool, dist: float) -> void:
	_step_timer -= delta
	if visible or not moving or dist > HEARD_FROM or _step_timer > 0.0:
		return
	_step_timer = 0.8
	Sfx.play(level, "step_%d" % (randi() % 6), lerpf(-24.0, -10.0, 1.0 - dist / HEARD_FROM), global_position)
	Effects.float_text(level, global_position + Vector3(0, 1.0, 0), Lang.t("tapp"), Color(0.7, 0.7, 0.75, 0.6))


## Now and then a groan, hiss, murmur or clank. The nearer the skeleton, the
## louder, more often and more urgent its voice; on the hunt it never stops.
func _voice(delta: float, dist: float) -> void:
	_voice_timer -= delta
	if _voice_timer > 0.0:
		return
	# 0 at the edge of hearing, 1 right next to the hero.
	var near := clampf(1.0 - dist / VOICE_RANGE, 0.0, 1.0)
	_voice_timer = lerpf(11.0, 2.5, near) * randf_range(0.7, 1.3)
	if _awake:
		_voice_timer *= 0.5
	if near <= 0.0:
		return
	if is_human():
		# A bandit has no groan of its own: it shouts while it hunts.
		if _awake:
			Effects.float_text(level, global_position + Vector3(0, 3.0 * _stats.size, 0), Lang.t(TAUNTS[randi() % TAUNTS.size()]), Color(1.0, 0.85, 0.6, 0.9))
		return
	var db := lerpf(-28.0, 2.0, pow(near, 1.4)) + (3.0 if _awake else 0.0)
	# A beast growls with a skeleton's voice, pitched to its size.
	var voice: Array = _stats.get("voice", ["voice_" + kind, 1.0, VOICE_WORDS.get(kind, "")])
	Sfx.play(level, "%s_%d" % [voice[0], randi() % 2], db, global_position, lerpf(0.9, 1.1, near) * voice[1])
	if is_beast() and _awake and near > 0.4:
		# On the hunt it snarls where the hero can see it, too.
		Effects.float_text(level, global_position + Vector3(0, 2.4 * _stats.size, 0), Lang.t(voice[2]).to_upper() + "!", Color(1.0, 0.7, 0.55, 0.9))
	if not visible:
		var word: String = Lang.t(voice[2])
		if near > 0.6:
			word = word.to_upper() + "!"
		Effects.float_text(level, global_position + Vector3(0, 1.6, 0), word, Color(0.75, 0.72, 0.8, lerpf(0.4, 0.9, near)))


## Caught on a table corner or a door frame: step aside for a moment and
## look for a new way.
func _check_stuck(delta: float, move: Vector3) -> void:
	var ground_speed := SmoothMotion.ground_speed(self)
	if move == Vector3.ZERO or ground_speed > float(_stats.speed) * 0.3:
		_stuck = maxf(0.0, _stuck - delta)
		return
	_stuck += delta
	if _stuck < 0.5:
		return
	_stuck = 0.0
	_repath = 0.0
	_path.clear()
	var side := move.cross(Vector3.UP).normalized()
	var cell := level.world_to_cell(global_position + side * Level.TILE * 0.6)
	if level.astar.is_in_boundsv(cell) and level.astar.is_point_solid(cell):
		side = -side
	elif randf() < 0.3:
		side = -side
	_detour = side
	_detour_time = 0.6


## Pushed into a tile with a pillar or furniture, where neither paths nor
## the hero's blade reach well: walk out to the nearest free tile.
func _step_out() -> Vector3:
	var cell := level.world_to_cell(global_position)
	# A tile walled off by stone blocks still has floor to stand on.
	if not level.astar.is_in_boundsv(cell) or not level.astar.is_point_solid(cell) or level.stone_cut(cell):
		return Vector3.ZERO
	for d in Level.DIRS:
		if level.astar.is_in_boundsv(cell + d) and not level.astar.is_point_solid(cell + d):
			var to := level.cell_to_world(cell + d) - global_position
			to.y = 0.0
			return to.normalized()
	return Vector3.ZERO


## Sets the skeleton on the hero at once, e.g. a cutthroat called by the chief.
func alert(at: Vector3) -> void:
	if not is_friend():
		_wake(at)


## Whether the skeleton has spotted the hero and is after them.
func is_hunting() -> bool:
	return _awake and not dead


## Whether the skeleton sees or hears the hero right now.
func _notices(player: Player, to_player: Vector3, dist: float, sees: bool) -> bool:
	var in_view := ahead_angle(to_player) <= SIGHT_CONE
	# Right up close it notices, unless the hero sneaks up from behind.
	if dist < TOUCH and (in_view or not player.sneaking or _awake):
		return true
	if dist < HEARING and player.is_noisy():
		return true
	if not sees or not player.is_lit():
		return false
	# Once hunting, a skeleton keeps its eyes on the hero all around.
	return _awake or in_view


func ahead_angle(to: Vector3) -> float:
	return ahead().angle_to(to)


## Starts or keeps up the hunt, heading for where the hero was noticed.
func _wake(at: Vector3) -> void:
	if not _awake:
		# A stroll's path is no use on the hunt.
		_path.clear()
		_repath = 0.0
	_awake = true
	_lost = 0.0
	_last_known = at


## Off the hunt: walk back to the post, then stand guard and look around.
func _rest(delta: float) -> Vector3:
	var to_home := _home - global_position
	to_home.y = 0.0
	if to_home.length() < 1.0:
		_path.clear()
		if _watch != Vector3.INF:
			# A guardian turns back to what it guards and keeps still.
			_model.rotation.y = lerp_angle(_model.rotation.y, _look_angle, 1.0 - exp(-3.0 * delta))
		else:
			_look_around(delta)
		return Vector3.ZERO
	if _repath <= 0.0 or _path.is_empty():
		_repath = 1.0
		_path.clear()
		for c in level.grid_path(level.world_to_cell(global_position), level.world_to_cell(_home)).slice(1):
			_path.append(level.cell_to_world(c))
		_path.append(_home)
	var to := _path[0] - global_position
	to.y = 0.0
	if to.length() < 0.4:
		_path.remove_at(0)
		return Vector3.ZERO
	return to.normalized() * 0.6


## A bandit off the hunt strolls from one spot near its home to the next,
## lingers a while, looks around and moves on.
func _roam(delta: float) -> Vector3:
	if _roam_pause > 0.0:
		_roam_pause -= delta
		_look_around(delta)
		return Vector3.ZERO
	if _path.is_empty():
		var home_cell := level.world_to_cell(_home)
		var here := level.world_to_cell(global_position)
		for attempt in 8:
			var c := home_cell + Vector2i(randi_range(-ROAM_TILES, ROAM_TILES), randi_range(-ROAM_TILES, ROAM_TILES))
			if c == here or not level.astar.is_in_boundsv(c) or level.astar.is_point_solid(c):
				continue
			for p in level.grid_path(here, c).slice(1):
				_path.append(level.cell_to_world(p) + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)))
			if not _path.is_empty():
				break
		if _path.is_empty():
			_roam_pause = 2.0
			return Vector3.ZERO
	var to := _path[0] - global_position
	to.y = 0.0
	if to.length() < 0.5:
		_path.remove_at(0)
		if _path.is_empty():
			_roam_pause = randf_range(2.0, 7.0)
		return Vector3.ZERO
	return to.normalized() * 0.45


func _look_around(delta: float) -> void:
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = randf_range(2.5, 5.0)
		_look_angle = _model.rotation.y + randf_range(-PI * 0.75, PI * 0.75)
	_model.rotation.y = lerp_angle(_model.rotation.y, _look_angle, 1.0 - exp(-3.0 * delta))


func _face(dir: Vector3, delta := -1.0) -> void:
	var target := atan2(dir.x, dir.z)
	if delta < 0.0:
		_model.rotation.y = target
	else:
		_model.rotation.y = lerp_angle(_model.rotation.y, target, 1.0 - exp(-12.0 * delta))


## A blow at the hero, or at a rival monster.
func _strike(target: Node3D) -> void:
	_cooldown = _stats.cooldown
	var slow: float = _stats.size
	_play_once("1H_Melee_Attack_Chop", 0.9 * slow)
	Sfx.play(self, "swing", -4.0, global_position)
	_anim.speed_scale = 1.0 / slow
	await get_tree().create_timer(0.45 * slow).timeout
	_anim.speed_scale = 1.0
	if dead or not is_inside_tree() or not is_instance_valid(target):
		return
	var d := target.global_position - global_position
	d.y = 0.0
	var rival := target as Enemy
	if rival != null:
		if not rival.dead and d.length() < float(_stats.reach) + 0.6 + rival.girth() and not level.stacked(self, rival):
			rival.hit_by_rival(_stats.damage, self)
		return
	var player := target as Player
	if player != null and d.length() < float(_stats.reach) + 0.6 and not level.stacked(self, player) \
			and not level.door_between(global_position, player.global_position):
		var before := player.hp
		player.take_damage(_stats.damage, global_position, self)
		# Minion blades and spider bites are sometimes poisoned.
		if player.hp < before and randf() < _stats.get("poison", POISON_CHANCE if kind == "wicht" else 0.0):
			player.afflict("gift")


## A bolt, an orb or fire at the hero, or at a rival monster.
func _shoot(target: Node3D) -> void:
	_cooldown = _stats.cooldown
	var magic: bool = kind == "magier"
	var fire: bool = _stats.get("fire", false)
	_play_once("Spellcast_Shoot" if magic else "1H_Ranged_Shoot", 0.9 if magic or fire else 0.7)
	await get_tree().create_timer(0.5 if magic or fire else 0.3).timeout
	if dead or not is_inside_tree() or not is_instance_valid(target) or level.stacked(self, target):
		return
	var origin := global_position + Vector3(0, 1.4 * (float(_stats.size) if fire else 1.0), 0)
	var aim := target.global_position + Vector3(0, 1.2, 0)
	Sfx.play(self, "magic" if magic or fire else "bow_%d" % (randi() % 3), -2.0, global_position)
	var shot := Projectile.spawn(level, origin, aim - origin, false, magic or fire, fire)
	shot.shooter = self
	shot.damage = _stats.damage
	if target is Enemy:
		shot.foe = target as Enemy
		shot.at_rival = true
