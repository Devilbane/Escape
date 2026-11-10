class_name Villager
extends CharacterBody3D
## A villager who goes about their day: works at their spot, walks over to
## the well or the square now and then, and comes back. Run into one to hear
## what they have to say. Driven by a small script, no AI service needed.

## A stroll through town (m/s): unhurried, the stride matched (see Stride).
const WALK_SPEED := 1.3
const RUN_SPEED := 3.6
## Body parts every model keeps; everything else (hats, weapons, books) is
## shown only when a role asks for it.
const BODY_PARTS := ["Body", "Head", "ArmLeft", "ArmRight", "LegLeft", "LegRight"]
const SAY_TIME := 4.0
## A line stays at least this long before the hero can get a new one by
## running into the villager again (or the whole line, if it is shorter).
## Without it, pushing against a villager swaps the text every bump and the
## bubble flickers.
const MIN_SAY_TIME := 2.5
## Two speech bubbles closer than this (metres, on the ground) lie over each
## other on screen: the bubble is about six metres wide. Only one of them
## shows at a time (see say and talker_near).
const BUBBLE_ROOM := 7.0
## The gold of the quest marks over the heads of villagers with a task.
const MARK_COLOR := Color(1.0, 0.82, 0.3)
## Waits this long for the hero to step aside before walking on.
const MAKE_WAY := WalkRules.MAKE_WAY
## Two villagers chatting (see VillageTalk) stand this far apart, and the
## one who stays put waits this long at most for the other to arrive.
const CHAT_GAP := 1.6
const CHAT_WAIT := 60.0
## After a chat nobody stops for another bump-chat for this long (seconds).
const BUMP_COOLDOWN := 45.0
## How close (centre to centre, metres) anyone else may come to a villager
## who keeps to their spot (a shopkeeper, the elder, the herald). Without
## it the village kid Pip ran right into Mira and stood inside her, and a
## bump hit him instead of her shop. Small enough for a path past a stall,
## big enough that the two bodies never overlap.
const PERSONAL_SPACE := 1.3
## Villagers who walk about keep at least this far from one another.
const PASSING_SPACE := 0.8

## A rosier face for a Rogue (see HairLook.tint_skin): the model's own skin
## turns pale yellow in the midday sun.
const SKIN_ROSY := Color(0.97, 0.85, 0.88)

## name: shown above the head; model; show: extra parts; hair: a look for a
## Rogue (see HairLook); skin: a tint for a Rogue's face; sex: "female" for a woman built on the Rogue (see
## BodyLook); cap: "post" for the postmaster's peaked cap (see PostCap); colors: body, legs, hat/cape; plan: how they spend the day (see _next_task); work: the
## animation at their spot; tool: something held in place of the model's own
## weapon ("hammer": the smith's hammer, see VillageProps.smith_hammer); lines:
## what they say, one after another.
const ROLES := {
	"0": {"name": "Dorfvorsteher Aldo", "model": "Mage", "show": ["Mage_Hat", "2H_Staff", "Mage_Cape"],
		"colors": [Color(0.55, 0.6, 0.8), Color(0.5, 0.5, 0.55), Color(0.45, 0.42, 0.7)], "plan": "stay", "work": "Idle",
		"lines": ["Willkommen in Lindenhain, Fremder!", "Das Haus mit dem Ziegeldach gehört jetzt dir.", "Ruh dich aus. Die Gruft ist weit weg."]},
	"1": {"name": "Schmied Gorm", "model": "Barbarian", "show": [], "tool": "hammer",
		"colors": [Color(0.55, 0.42, 0.32), Color(0.4, 0.36, 0.34), Color(1, 1, 1)], "plan": "shop", "work": "1H_Melee_Attack_Chop", "sound": "hit",
		"lines": ["Brauchst du eine Klinge? Ich schmiede die besten im Tal.", "Heiß muss das Eisen sein, sonst bricht es.", "Bring mir altes Eisen, ich schmelze es ein und mache dir etwas Neues daraus.", "Verbeulte Rüstung? Leg sie auf den Amboss."]},
	"2": {"name": "Bäuerin Lene", "model": "Rogue", "show": [], "sex": "female",
		"colors": [Color(0.9, 0.75, 0.45), Color(0.55, 0.45, 0.3), Color(0.85, 0.55, 0.3)], "plan": "work", "work": "PickUp",
		"lines": ["Die Kürbisse sind dieses Jahr riesig!", "Das Korn muss rein, bevor der Frost kommt.", "Hast du Hunger? Im Wirtshaus gibt es Suppe."]},
	"3": {"name": "Holzfäller Bruno", "model": "Barbarian", "show": ["2H_Axe", "Barbarian_Hat"],
		"colors": [Color(0.75, 0.35, 0.3), Color(0.35, 0.4, 0.3), Color(0.6, 0.45, 0.3)], "plan": "work", "work": "2H_Melee_Attack_Chop", "sound": "hit",
		"lines": ["Holla! Du kommst vom Friedhof? Da geht doch keiner hin.", "Folge dem Weg, dann kommst du ins Dorf.", "Ein Baum am Tag, so hält man den Wald gesund.", "Am Waldteich westlich vom Dorf schnüren oft Füchse durchs Gras."]},
	"4": {"name": "Wache Ulrich", "model": "Knight", "show": ["Knight_Helmet", "1H_Sword", "Round_Shield", "Knight_Cape"],
		"colors": [Color(1, 1, 1), Color(0.8, 0.8, 0.85), Color(0.35, 0.45, 0.8)], "plan": "patrol", "work": "Idle",
		"lines": ["Halt! Ach, du bist der Neue. Willkommen.", "Seit Jahren kam keiner mehr aus der Gruft.", "Ich halte Wache. Hier bist du sicher."]},
	"5": {"name": "Zecher Fritz", "model": "Barbarian", "show": ["Mug"],
		"colors": [Color(0.4, 0.55, 0.4), Color(0.45, 0.35, 0.28), Color(1, 1, 1)], "plan": "sit", "work": "Sit_Floor_Idle",
		"lines": ["Prost! Auf die Freiheit!", "Das Bier hier ist das beste diesseits der Berge.", "Setz dich doch, erzähl von da unten!"]},
	"6": {"name": "Krämerin Mira", "model": "Rogue", "show": ["Rogue_Cape"], "sex": "female",
		"colors": [Color(0.7, 0.35, 0.6), Color(0.35, 0.3, 0.45), Color(0.6, 0.3, 0.5)], "plan": "shop", "work": "Interact",
		"lines": ["Brot, Käse, Seile, Fackeln: alles für den Alltag!", "Ich kaufe auch, was du aus dem Verlies mitbringst.", "Für einen Helden mache ich einen guten Preis.", "Wurst für die Füchse? Die leben auf der Wiese am Waldteich, westlich vom Dorf."]},
	"7": {"name": "Pip", "model": "Rogue", "show": [], "scale": 0.72, "hair": {"style": "spiky", "color": "blond"}, "skin": SKIN_ROSY,
		"colors": [Color(0.45, 0.6, 0.9), Color(0.6, 0.45, 0.3), Color(0.9, 0.8, 0.3)], "plan": "wander", "work": "Cheer", "herds": true, "pal": "pippi",
		"lines": ["Fang mich doch!", "Bist du ein echter Abenteurer?", "Mama sagt, in der Gruft spukt es!", "Das sind meine Ziegen! Ich passe auf sie auf.", "Die Gänse hören auf niemanden. Nicht mal auf mich.", "Der Hund bleibt bei den Ziegen, wo ich bin.", "Das ist meine Freundin Pippi! Sie hütet die Gänse und die Ziegen mit mir."]},
	# Pip's friend: a red-haired girl with long pigtails and freckles who minds
	# the geese and the goats with him. She is not on the map: Outdoor puts her
	# beside Pip (see VillageFarm.pippi_home), so she needs no map letter.
	"pippi": {"name": "Pippi", "model": "Rogue", "show": [], "scale": 0.7,
		"hair": {"style": "short", "color": "ginger", "tails": true, "freckles": true, "smile": true, "ear_gem": true}, "skin": SKIN_ROSY,
		"colors": [Color(0.8, 0.35, 0.4), Color(0.45, 0.35, 0.3), Color(1, 1, 1)], "plan": "wander", "work": "Cheer", "herds": true, "pal": "7",
		"lines": ["Hallo! Ich bin Pippi. Pip und ich hüten die Gänse und die Ziegen.", "Pip ist mein bester Freund. Wir spielen Fangen auf der Wiese!", "Die Gänse zwicken, wenn man ihnen den Rücken zudreht.", "Die Ziegen mögen dich, wenn du ruhig bleibst.", "Die Gänse und Ziegen weiden an der Wiese südlich und westlich vom Dorf."]},
	"8": {"name": "Gelehrter Odo", "model": "Mage", "show": ["Mage_Hat", "Spellbook_open"],
		"colors": [Color(0.35, 0.3, 0.45), Color(0.3, 0.3, 0.35), Color(0.3, 0.25, 0.4)], "plan": "stroll", "work": "Spellcast_Raise",
		"lines": ["Faszinierend, du lebst! Das Verlies gilt als unentrinnbar.", "In meinen Büchern steht etwas über Wächter in Rüstung...", "Ruhe, bitte. Ich lese."]},
	"9": {"name": "Wasserträgerin Hanna", "model": "Rogue", "show": [], "sex": "female", "hair": {"style": "natural", "color": "blond"},
		"colors": [Color(0.4, 0.65, 0.75), Color(0.45, 0.4, 0.35), Color(1, 1, 1)], "plan": "carry", "work": "PickUp",
		"lines": ["Frisches Wasser vom Brunnen!", "Puh, die Eimer sind schwer.", "Der Brunnen ist so alt wie das Dorf."]},
	"K": {"name": "Herold Konrad", "model": "Knight", "show": ["Knight_Cape", "Badge_Shield"],
		"colors": [Color(0.4, 0.5, 0.9), Color(0.85, 0.75, 0.4), Color(0.3, 0.4, 0.85)], "plan": "stay", "work": "Idle",
		"lines": ["Ich bin der Herold der Krone. Ich rufe die Neuigkeiten aus.", "Bleib in der Nähe, gleich gibt es Neues!", "Das Amt der Krone kümmert sich um Recht und Steuern."]},
	"O": {"name": "Priesterin Elsbeth", "model": "Mage", "show": ["Mage_Cape", "2H_Staff"],
		"colors": [Color(0.95, 0.93, 0.85), Color(0.9, 0.88, 0.8), Color(0.95, 0.8, 0.4)], "plan": "work", "work": "Spellcast_Raise",
		"lines": ["Die Götter haben dich aus der Tiefe geführt.", "Der Tempel steht allen offen, Tag und Nacht.", "Möge das Licht deinen Weg erhellen."]},
	"G": {"name": "Gildenmeisterin Ragna", "model": "Barbarian", "show": ["Barbarian_Round_Shield", "1H_Axe", "Barbarian_Cape"],
		"colors": [Color(0.6, 0.25, 0.2), Color(0.3, 0.28, 0.26), Color(0.7, 0.2, 0.15)], "plan": "stay", "work": "Idle",
		"lines": ["Die Gilde sucht Leute wie dich. Wer aus dem Verlies kommt, ist zäh.", "Bald gibt es Aufträge: Wölfe im Wald, Räuber am Pass.", "Zeig mir deine Narben, dann reden wir."]},
	"M": {"name": "Postmeister Anselm", "model": "Rogue", "show": [], "hair": {"style": "short", "color": "black"}, "cap": "post",
		"colors": [Color(0.95, 0.8, 0.3), Color(0.35, 0.35, 0.5), Color(1, 1, 1)], "plan": "carry", "work": "PickUp",
		"lines": ["Ein Brief für dich? Noch nicht, aber bald bestimmt.", "Ich bringe die Post zu jedem Haus im Dorf.", "Die Postkutsche kommt jeden dritten Tag."]},
	"Z": {"name": "Barbier Benno", "model": "Rogue", "show": [], "hair": {"style": "mohawk", "color": "fire"},
		"colors": [Color(0.95, 0.95, 0.95), Color(0.25, 0.25, 0.3), Color(1, 1, 1)], "plan": "shop", "work": "Interact",
		"lines": ["Haare schneiden, färben, tätowieren: Bei mir wirst du ein neuer Mensch!", "Ein Irokese steht dir bestimmt. Oder gleich in Flammen?", "Halt still, sonst wird die Tätowierung schief."]},
	"Y": {"name": "Bankier Goldwin", "model": "Mage", "show": ["Mage_Hat"],
		"colors": [Color(0.25, 0.45, 0.3), Color(0.25, 0.25, 0.28), Color(0.2, 0.35, 0.25)], "plan": "work", "work": "Interact",
		"lines": ["Kupfer ist bei uns sicherer als in jeder Truhe.", "Die Bank der Krone öffnet bald ihre Schalter für Abenteurer.", "Zinsen? Nur für treue Kunden."]},
	"S": {"name": "Steinmetz Hagen", "model": "Barbarian", "show": ["1H_Axe"],
		"colors": [Color(0.6, 0.58, 0.55), Color(0.4, 0.38, 0.36), Color(0.7, 0.68, 0.64)], "plan": "shop", "work": "1H_Melee_Attack_Chop", "sound": "hit",
		"lines": ["Steinblöcke, sauber behauen! Bau dir, was du willst.", "Eine Mauer hält länger als jeder Zaun.", "Stapel sie versetzt, dann hält die Mauer besser."]},
	# Not one of the village's own: the wandering merchant who comes on
	# certain nights only (see Wanderer). He is put up by Outdoor himself,
	# never from the map.
	"%": {"name": "Wanderhändler Zarek", "model": "Mage", "show": ["Mage_Hat", "Mage_Cape"],
		"colors": [Color(0.3, 0.22, 0.42), Color(0.22, 0.2, 0.26), Color(0.16, 0.2, 0.42)], "plan": "stay", "work": "Interact",
		"lines": ["Psst! Waren aus fernen Ländern, nur heute Nacht!", "Wenn der Morgen graut, bin ich schon wieder auf der Straße.", "Mondsilber, Glimmermoos, Pilze aus fernen Wäldern: Zutaten für jedes Rezept!", "Jede dritte Nacht komme ich vorbei. Halt die Augen offen."]},
}

## What the herald calls out on the square, one after another.
const NEWS := [
	"Hört, hört! Ein Held ist aus der alten Gruft entkommen!",
	"Hört, hört! Die Krone sucht mutige Helden. Meldet euch in der Abenteurergilde!",
	"Hört, hört! Morgen ist Markttag. Die Krämerin hat frisches Brot!",
	"Hört, hört! Briefe aus der Hauptstadt liegen auf der Post bereit.",
	"Hört, hört! Die Bank der Krone verwahrt euer Kupfer sicher.",
	"Hört, hört! Heute Abend gibt es Segen im Tempel für alle!",
	"Hört, hört! Jede dritte Nacht kommt der Wanderhändler Zarek mit seinem Karren ins Dorf!",
]
## How long the village listens to the herald (seconds).
const LISTEN_TIME := 13.0
## Who stays up at night: the guard keeps watch, the drinker stays at the
## tavern, the temple is open day and night and the wandering merchant only
## comes at night. Everyone else goes home to sleep at nightfall (see
## Outdoor.set_hour) and comes out in the morning.
const NIGHT_OWLS := ["4", "5", "O", "%"]
## Out in the dark everyone about on honest business carries a torch: the
## guard on his rounds, the priestess at the temple, and whoever is still
## walking home at nightfall. Not those who keep to one lit spot all night,
## the drinker on his bench and the wandering merchant by his lantern-hung
## cart (their plans). Thieves and bandits are no villagers and go dark.
const UNLIT_PLANS := ["sit", "stay"]
## The torch's light: warm, flickering, a few tiles around the bearer.
## Without shadows and only while someone is out, to stay cheap in the
## browser (a handful of villagers at most).
const TORCH_COLOR := Color(1.0, 0.6, 0.28)
const TORCH_ENERGY := 1.7
const TORCH_RANGE := 12.0
## The woodcutter splits wood on a felled trunk beside his spot (see
## set_chopping and Outdoor._build_chopping_log) instead of swinging at the
## air. In his two-handed chop the lower blade of the axe comes down in front
## of him, a little to his left; BITE_TIME is the moment in that animation
## when it reaches the top of the trunk, and BITE_POINT is where the blade
## then is, in his own frame (+z ahead). Both were measured from the
## Barbarian model (tests/woodcutter.gd checks they still match).
const BITE_TIME := 0.815
const BITE_POINT := Vector3(-0.215, 0.41, 1.59)
## The trunk he chops: its middle in his own frame, its radius and length.
## It lies across his way, settled a little into the ground, and its top is
## where the blade bites.
const LOG_CENTRE := Vector3(-0.3, 0.12, 1.6)
const LOG_RADIUS := 0.34
const LOG_LENGTH := 3.0
## How long the axe sticks in the wood before he wrenches it out.
const BITE_HOLD := 0.3
## The smith hammers hot iron on an anvil beside his spot in the same way
## (see Outdoor._build_anvil): in his one-handed chop the hammer comes down in
## front of him, a little to his right. HAMMER_TIME is the moment in that
## animation when its face reaches the top of the iron on the anvil, and
## HAMMER_POINT is where the face then is, in his own frame (+z ahead).
## Both were measured from the Barbarian model (tests/smith.gd checks they
## still match). HAMMER_FACE is the middle of the hammer's striking face in
## the hand's frame (the frame of the axe it stands in for).
const HAMMER_TIME := 0.587
const HAMMER_POINT := Vector3(-0.64, 0.985, 1.185)
const HAMMER_FACE := Vector3(-0.17, 0.8, 0)
## The anvil's foot in his frame: the hot iron on its face (see
## VillageProps.HOT_IRON_AT) lies under HAMMER_POINT.
const ANVIL_AT := Vector3(-0.6, 0, 1.245)
## A hammer rings off the iron instead of sticking: only a short beat on it.
## Then it springs back up the way it came (the swing played backwards at
## HAMMER_REBOUND times its speed) to where it was raised high, at
## HAMMER_RAISED in the swing, clear of the anvil, and either comes down
## again from there or he lowers it and rests (see HAMMER_LOWERED).
const HAMMER_HOLD := 0.09
const HAMMER_REBOUND := 1.4
const HAMMER_RAISED := 0.5
## After the last blow of a few the swing plays backwards all the way down
## to where it started, the hammer hanging as it does at rest.
const HAMMER_LOWERED := 0.04
## Weapon parts of the models; hidden while all is quiet (see sheathe_weapons).
const WEAPON_PARTS := ["1H_Sword", "1H_Axe", "2H_Axe"]
## How long a drawn blade stays out after the danger is gone, so it does not
## flicker when a slime wavers at the edge of sight.
const SHEATHE_DELAY := 1.5

var level: Outdoor
var role := "7"
var home := Vector2i.ZERO
var station: Dictionary = {}
## Swallowed by a slime (see SlimeGrowth.gulp): hidden inside it until it falls.
var eaten := false
## A slime going for them (see alarm): the brave draw a blade and fight it
## ("fight"), the others run into the nearest house and wait there until it
## is gone ("hide").
var threat: Enemy = null
var brave := false
var _blow_cool := 0.0
## Counts down after the danger; at zero the blade is sheathed. -1: not waiting.
var _sheathe_in := -1.0
var _calm_check := 0.0
var display_name := ""
var _info: Dictionary
var _model: Node3D
var _anim: AnimationPlayer
var _rng := RandomNumberGenerator.new()
var _path: Array[Vector3] = []
var _task := ""
var _task_time := 0.0
var _work_pause := 0.0
var _speed := WALK_SPEED
## Ground walked since the last footstep sounded (see TownsfolkSteps).
var _stepped := 0.0
## Where the villager stood at the last tick (see _lift_onto_toes).
var _last_spot := Vector3.INF
var _waiting := 0.0
var _bubble: SpeechBubble
var _bubble_time := 0.0
## How long the current line still holds before a new bump may replace it.
var _bubble_hold := 0.0
## The name over the head, shown once the hero has talked to us.
var _name_tag: Label3D
## The quest mark over the head: "!" for a task to offer, "?" for one to
## hand in (see Quests.mark), hidden when there is neither.
var _quest_mark: Label3D
var _mark_base := 0.0
var _mark_time := 0.0
var _line := 0
var _current_anim := ""
var _look_at := Vector3.INF
var _greeted := false
## Who the villager listens to while gathered on the square.
var _listen_to := Vector3.INF
var _news := 0
## Night has fallen, and whether the villager is inside their house asleep
## (hidden, and nobody to talk to or trade with until morning).
var night := false
var at_home := false
## The room this villager takes up (metres, see Footprint): half a body width.
var radius := 0.5
var _layer := 1
## The villager we are chatting with (see VillageTalk), or null.
var chat_partner: Villager = null
## Seconds until we may stop for a chat after bumping into someone again (set
## when any chat ends), so a pair does not re-trigger endlessly.
var bump_cool := 0.0
## Set when someone else (the hero, mostly) speaks to us during a chat: the
## chat is over.
var chat_broken := false
## Singing a drinking song (see DrinkingSongs), between two lines too. Any
## other line ends it; while it lasts, nobody pulls us into a chat.
var singing := false
## Whether we stay seated through the chat (the drinker on his bench).
var _chat_sitting := false
## The torch in the hand at night (see carries_torch), made the first night
## it is needed, the left hand's own things hidden while it burns, and the
## light it throws.
var _torch: Node3D
var _torch_light: OmniLight3D
var _torch_hidden: Array[Node3D] = []
var _torch_time := 0.0
## Where the woodcutter (or the smith) stands to work and which way he faces
## then (INF: neither, or nothing to strike), the chips (or sparks) that fly
## at each blow, and the blow under way: whether the blade or hammer has
## struck yet, and how long it still rests there.
var _chop_stand := Vector3.INF
var _chop_face := Vector3.FORWARD
var _chips: CPUParticles3D
var _bitten := false
var _stuck := 0.0
## The smith's hammer on its way back up after a blow (the swing played
## backwards), and how many more blows follow before he rests.
var _rebound := false
var _blows := 0
static var _wood: StandardMaterial3D
## Feeding the birds (see VillageBirds): how many handfuls of seed are thrown,
## how far ahead they land (metres), when in the throw the seed leaves the
## hand (seconds), and the breath between two throws.
const SEED_TOSSES := 3
const SEED_AHEAD := 2.2
const SEED_RELEASE := 0.42
const SEED_PAUSE := Vector2(0.7, 1.6)
## What the feeder calls out to the birds (for the event log, see Events.say).
const SEED_CALLS := ["Put, put, put! Kommt, ihr Kleinen!", "Hier, ihr Piepmätze, frische Körner!", "Na, wer hat Hunger?"]
## A handful of seed leaves the hand at `from` and lands around `to` (both
## in world space).
signal seeds_tossed(from: Vector3, to: Vector3)
## The handfuls still to throw, the seconds into this throw (or, below zero,
## to the next), whether this throw has let go yet, and where the seed lands.
var _tosses := 0
var _toss_clock := 0.0
var _tossed := false
var _seed_spot := Vector3.INF
var _skeleton: Skeleton3D
## The game of tag, cartwheels and somersaults this child plays (see KidPlay), once begun.
var _kid: KidPlay
var _head_top := -1.0


func setup(owner_level: Outdoor, role_char: String, cell: Vector2i) -> void:
	level = owner_level
	role = role_char
	home = cell
	_info = ROLES[role]
	display_name = Lang.t(_info.name)
	_rng.seed = hash(role) + cell.x * 31 + cell.y
	brave = not shelters()


func _ready() -> void:
	SmoothMotion.follow_ticks(self)
	add_to_group(Footprint.GROUP)
	radius = 0.5 * _info.get("scale", 1.0)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = 2.2 * _info.get("scale", 1.0)
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)
	_model = load("res://assets/characters/%s.glb" % _info.model).instantiate()
	_model.scale = Vector3.ONE * _info.get("scale", 1.0) * BodyLook.scale_of(_info.get("sex", BodyLook.DEFAULT))
	add_child(_model)
	_dress()
	# A woman built on the Rogue model gets her own body (see BodyLook); the
	# dyes stay on, they belong to the parts, not to the meshes.
	BodyLook.apply(_model, _info.get("sex", BodyLook.DEFAULT))
	# Everyone on the Rogue model has combed hair, some a haircut of their own.
	if _info.has("hair") or _info.model == "Rogue":
		HairLook.apply(_model, HairLook.checked(_info.get("hair", HairLook.DEFAULT)))
		if _info.has("skin"):
			HairLook.tint_skin(_model, _info.skin)
	if _info.get("cap", "") == "post":
		PostCap.put_on(_model)
	# Weave, leather grain and scratched metal on the clothes (see GearLook).
	GearLook.dress_body(_model, "outfit")
	_anim = _model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Walking_A", "Walking_B", "Running_A", "Sit_Floor_Idle"]:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_bubble = SpeechBubble.new()
	_bubble.position.y = 3.0 * _info.get("scale", 1.0) + 0.15
	add_child(_bubble)
	_name_tag = Label3D.new()
	_name_tag.text = display_name
	_name_tag.font = SpeechBubble.FONT
	_name_tag.font_size = 30
	_name_tag.pixel_size = 0.011
	_name_tag.outline_size = 10
	_name_tag.outline_modulate = Color(0.05, 0.03, 0.06, 0.85)
	_name_tag.modulate = Color(1, 0.95, 0.85, 1)
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.no_depth_test = true
	_name_tag.render_priority = 18
	_name_tag.outline_render_priority = 17
	_name_tag.position.y = 2.5 * _info.get("scale", 1.0) + 0.25
	_name_tag.visible = is_known()
	add_child(_name_tag)
	_quest_mark = Label3D.new()
	_quest_mark.font = SpeechBubble.FONT
	_quest_mark.font_size = 140
	_quest_mark.pixel_size = 0.011
	_quest_mark.outline_size = 26
	_quest_mark.outline_modulate = Color(0.05, 0.03, 0.06, 0.9)
	_quest_mark.modulate = MARK_COLOR
	_quest_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_quest_mark.no_depth_test = true
	_quest_mark.render_priority = 18
	_quest_mark.outline_render_priority = 17
	_mark_base = 2.5 * _info.get("scale", 1.0) + 1.1
	_quest_mark.position.y = _mark_base
	_quest_mark.visible = false
	add_child(_quest_mark)
	rotation.y = _rng.randf() * TAU
	_start("sit" if _info.plan == "sit" else "work", _rng.randf_range(2.0, 6.0))


## Hats, capes and tools for the role, and clothes in the role's colours.
func _dress() -> void:
	dress_model(_model, _info)
	sheathe_weapons(_model, _info)


## Blades and axes are put away until there is danger (see _draw_blade): the
## model's own weapon is hidden, except for the tool of a trade that swings it
## all day (the woodcutter's and the mason's axe). Shields and helmets stay.
static func sheathe_weapons(model: Node3D, info: Dictionary) -> void:
	if String(info.get("work", "")).contains("Chop"):
		return
	for part in WEAPON_PARTS:
		var mesh := model.find_child(part, true, false)
		if mesh is Node3D:
			(mesh as Node3D).visible = false


## Shows the parts in info.show (and the body), hides the rest, puts
## info.tool in the right hand and dyes the clothes in info.colors (body,
## legs, hat or cape). Also used for the people
## made in the map workshop (see DungeonNpc).
static func dress_model(model: Node3D, info: Dictionary) -> void:
	var show: Array = info.show
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var part := String(mi.name)
		var base := part.get_slice("_", part.get_slice_count("_") - 1)
		var is_body := false
		for b in BODY_PARTS:
			if part.ends_with("_" + b):
				is_body = true
				base = b
		if not is_body and not part in show:
			mi.visible = false
			continue
		var color := Color.WHITE
		if base == "Body":
			color = info.colors[0]
		elif base.begins_with("Leg"):
			color = info.colors[1]
		elif base.begins_with("Arm"):
			color = Color.WHITE.lerp(info.colors[0], 0.5)
		elif part.ends_with("Hat") or part.ends_with("Cape") or part.ends_with("Helmet"):
			color = info.colors[2]
		if color != Color.WHITE:
			var mat := mi.get_active_material(0)
			if mat is StandardMaterial3D:
				var dyed: StandardMaterial3D = mat.duplicate()
				dyed.albedo_color = color
				mi.material_override = dyed
	if info.get("tool", "") == "hammer":
		# In the hand slot, where the one-handed axe would hang, so it swings
		# exactly as the axe does.
		var axe: Node3D = model.find_child("1H_Axe", true, false)
		if axe:
			var hammer := VillageProps.smith_hammer(axe.get_parent())
			hammer.name = "SmithHammer"
			hammer.transform = axe.transform


func play(anim_name: String, blend := 0.25) -> void:
	# Anything else to do (the hero comes to talk, night falls) pulls a
	# stuck axe out of the trunk at once.
	_anim.speed_scale = 1.0
	_stuck = 0.0
	_rebound = false
	if _current_anim == anim_name and _anim.is_playing():
		return
	_current_anim = anim_name
	_anim.play(anim_name, blend)
	# Off the toes (see _stride) when anything else begins.
	_model.position.y = 0.0


## Walks in `anim` at up to `speed`: no faster than its feet step (see
## Stride), played just as fast as the planted foot must travel, rising
## onto the toes at each push-off. Returns the speed really walked.
func _stride(anim: String, speed: float) -> float:
	var size := _model.scale.x
	var walked := minf(speed, Stride.top_speed("kaykit", anim, size))
	play(anim)
	_anim.speed_scale = Stride.playback("kaykit", anim, size, walked)
	return walked


## Up on the toes at each push-off while really walking (see Stride.lift),
## flat-footed while standing, whatever is playing. From how far the
## villager got since the last tick.
func _lift_onto_toes(delta: float) -> void:
	var moved := Vector2(global_position.x - _last_spot.x, global_position.z - _last_spot.z).length()
	_last_spot = global_position
	var speed := moved / delta if delta > 0.0 and moved < 1.0 else 0.0
	_model.position.y = Stride.lift(_anim, _current_anim, _model.scale.x, speed)


# --- The day's plan -----------------------------------------------------------

## Set while a game loaded at night puts the village to bed: no doors swing.
var _settling := false


func _start(task: String, time: float) -> void:
	_task = task
	if task != "mend":
		_wield_wall_hammer(false)
	# Mending goes on until the brick is whole (see _mend), not for a set time.
	_task_time = 600.0 if task in ["mend", "defend"] else time
	_work_pause = 0.0
	if task in ["home", "hide"] and not at_home:
		_hide_inside(true, true)


# --- Mending the village wall -------------------------------------------------

## The brick of the village wall the stonemason (or the woodcutter, who lends a hand, 50% faster together) is on his way to or mending.
var mend_brick: WallBrick = null


## Whether the villager is free to see to the wall: out at his work or just
## standing about, not running from a slime or listening to the herald.
## The stonemason and the woodcutter mend; only the mason is called out of bed.
func can_mend() -> bool:
	if not role in VillageWall.MENDERS or eaten or threat != null:
		return false
	# Asleep at night the mason is called out for a hurt wall (see works_late).
	if (at_home or not visible) and not (role == "S" and night and at_home and level.village_wall.job(level) != null):
		return false
	if mend_brick != null and _task in ["walk", "mend"]:
		return false
	if at_home:
		return true
	return _task in ["work", "idle"] or (_task == "walk" and get_meta("then", "") in ["work", "idle"])


## Walks up to a hurt brick of the wall and builds it up (see VillageWall).
func mend(brick: WallBrick) -> void:
	mend_brick = brick
	if at_home:
		_hide_inside(false, true)
	_walk_to(level.village_wall.stand_of(level, brick), WALK_SPEED * 1.3, "mend")


func _mend(delta: float) -> void:
	var brick := mend_brick
	var wall := level.village_wall
	if brick == null or not is_instance_valid(brick) or not brick.is_damaged() or wall.shut_wanted \
			or level.village_alarm.raised or VillageWall.slime_near(level, brick.global_position, VillageWall.MEND_SAFE):
		_finish_mending()
		return
	# Shoved off his place: back to the wall.
	var spot := wall.stand_of(level, brick)
	var off := Vector2(global_position.x - spot.x, global_position.z - spot.z)
	if off.length() > 1.6:
		if level.world_to_cell(global_position) == level.world_to_cell(spot):
			# Already on the spot's tile there is no path to walk (see _walk_to):
			# step straight to the spot, or he would stand there doing nothing.
			var to := spot - global_position
			to.y = 0.0
			play("Walking_A")
			_move_to(global_position + to.normalized() * minf(to.length(), _stride("Walking_A", WALK_SPEED) * delta))
			_turn_to(to, delta)
		else:
			_walk_to(spot, WALK_SPEED, "mend")
		return
	_turn_to(brick.nearest_point(global_position) - global_position, delta)
	var work: String = _info.work
	# The woodcutter lends a hand with a hammer, not his axe: the one-handed
	# hammer blow, the same swing the smith's hammer makes.
	if role == "3":
		work = "1H_Melee_Attack_Chop"
		_wield_wall_hammer(true)
	if not (_anim.is_playing() and _current_anim == work):
		_current_anim = work
		_anim.play(work, 0.15)
		get_tree().create_timer(0.45).timeout.connect(func():
			if is_inside_tree() and _task == "mend":
				Sfx.play(self, "step_scree_%d" % _rng.randi_range(0, 5), -17.0, global_position, 1.5))
	if brick.mend(VillageWall.MEND_PER_SECOND * wall.pace(level, self) * delta):
		_finish_mending()


## The woodcutter swaps his axe for a hammer while he mends the wall, and back.
func _wield_wall_hammer(on: bool) -> void:
	if role != "3" or _model == null:
		return
	var hammer := _model.find_child("WallHammer", true, false) as Node3D
	var axe := _model.find_child("2H_Axe", true, false) as Node3D
	if on and hammer == null:
		var slot := _model.find_child("1H_Axe", true, false) as Node3D
		if slot == null:
			return
		hammer = VillageProps.smith_hammer(slot.get_parent())
		hammer.name = "WallHammer"
		hammer.transform = slot.transform
	if hammer != null:
		hammer.visible = on
	if axe != null:
		axe.visible = not on


## The brick is whole (or the work cannot go on): the next hurt brick, else back to his stand.
func _finish_mending() -> void:
	mend_brick = null
	var taken: Array[WallBrick] = []
	for v: Villager in level.villagers:
		if v != self and v.mend_brick != null and is_instance_valid(v.mend_brick):
			taken.append(v.mend_brick)
	var next := level.village_wall.job_for(level, role, taken)
	if next != null and can_mend_next():
		mend(next)
	else:
		_start("idle", 0.5)


func can_mend_next() -> bool:
	return not eaten and not at_home and threat == null


# --- The guard at the west gate -----------------------------------------------

## Seconds until the guard may call out a slime at the gate again.
var _watch_pause := 0.0


## The guard stands inside the west gate and looks out. At the first slime he
## sees he calls out once; the gate then shuts and he takes his post with the
## other fighters (see GuardWatch, VillageWall._muster).
func _watch(delta: float) -> void:
	_watch_pause = maxf(0.0, _watch_pause - delta)
	var slime := GuardWatch.slime_in_sight(level)
	var gate := GuardWatch.west_gate(level)
	if gate != null:
		_turn_to(gate.global_position - global_position, delta)
	if _horn_wait and global_position.distance_to(GuardWatch.post(level)) < HORN_ARRIVED:
		_horn_wait = false
		_horn_left = WarHorn.LENGTH
		WarHorn.sound(level)
	if _horn_left > 0.0:
		# Blowing the alarm horn: arms up, facing the way the horn points.
		_horn_left -= delta
		_task_time = maxf(_task_time, 1.0)
		_turn_to(_horn_at - global_position, delta)
		play("Cheer")
	else:
		play("Idle")
	if slime != null and _watch_pause <= 0.0:
		_watch_pause = GuardWatch.CALL_PAUSE
		say(Lang.t(GuardWatch.CALL))
		Events.alarm("gate")
		Events.tell(Lang.t(GuardWatch.NEWS), GuardWatch.COLOR)
		_task_time = maxf(_task_time, GuardWatch.STAND_MIN)


## Seconds the guard still blows the alarm horn, and where it stands (see WarHorn).
var _horn_left := 0.0
## Whether he is on his way to the horn to blow it, and how close counts as there (metres).
var _horn_wait := false
const HORN_ARRIVED := 2.5
var _horn_at := Vector3.INF


## Whether the guard can run to the alarm horn and blow it now: at his round or
## at the gate, not fighting, hiding, at home or eaten, and not too far away.
func can_blow_horn(at: Vector3) -> bool:
	if role != "4" or eaten or at_home or not visible or threat != null or defends():
		return false
	return global_position.distance_to(at) <= WarHorn.REACH


## The guard walks to the alarm horn (it stands beside his post at the gate)
## and blows it from there (see WarHorn.blow).
func sound_alarm(at: Vector3) -> void:
	_horn_at = at
	_horn_wait = true
	_horn_left = 0.0
	if _task == "watch" and global_position.distance_to(GuardWatch.post(level)) < HORN_ARRIVED:
		# Already at his post: he blows it now.
		_horn_wait = false
		_horn_left = WarHorn.LENGTH
		_task_time = maxf(_task_time, WarHorn.LENGTH)
		WarHorn.sound(level)
		return
	say(Lang.t("Ins Horn! Alarm, Alarm!"))
	_walk_to(GuardWatch.post(level), WALK_SPEED * 1.6, "watch")
	_task_time = maxf(_task_time, WarHorn.LENGTH)


# --- Defending the wall -------------------------------------------------------

## How far over the wall a defender strikes (metres, from his hands), how far
## he sees a slime outside, and how far from his post he steps to meet it.
const WALL_REACH := 3.4
const DEFEND_SIGHT := 16.0
const POST_ROOM := 5.0
var defend_post := Vector3.INF


func defends() -> bool:
	return _task == "defend" or (_task == "walk" and get_meta("then", "") == "defend")


## Whether this villager is running, fighting or sheltering right now (no time for
## customers, see VillagerPost).
func endangered() -> bool:
	return threat != null or defends() or _task in ["fight", "hide"]


## Whether a brave villager can be sent to a post: at his work, not running or fighting.
func can_defend() -> bool:
	if not brave or eaten or at_home or threat != null or defends():
		return false
	return _task in ["work", "idle", "listen", "watch"] or (_task == "walk" and get_meta("then", "") in ["work", "idle", "listen", "watch"])


## Out of the wall's reach: run in through the gate before it shuts.
func go_inside(way_in: Vector3) -> void:
	if _task in ["fight", "hide"] or at_home or eaten:
		return
	_walk_to(way_in, RUN_SPEED, "idle")


## Draws a blade and takes a post by the wall (see VillageWall).
func defend(post: Vector3) -> void:
	mend_brick = null
	leave_chat()
	_listen_to = Vector3.INF
	defend_post = post
	_draw_blade(true)
	say(Lang.t(VillageWall.MUSTER_CALL))
	_walk_to(post, RUN_SPEED, "defend")


## Moves a defender to a new post along the wall, unless a slime is at them.
func repost(post: Vector3) -> void:
	if _task != "defend" or Vector2(post.x - defend_post.x, post.z - defend_post.z).length() < POST_ROOM:
		return
	if VillageWall.slime_near(level, global_position, WALL_REACH + 2.0):
		return
	defend_post = post
	_walk_to(post, RUN_SPEED, "defend")


func _defend(delta: float) -> void:
	if not level.village_wall.shut_wanted or defend_post == Vector3.INF:
		defend_post = Vector3.INF
		_sheathe_later()
		_start("idle", _rng.randf_range(0.5, 2.0))
		return
	var slime := VillageWall.nearest_slime(level, global_position, DEFEND_SIGHT)
	if slime == null:
		play("Idle")
		return
	var to := slime.global_position - global_position
	to.y = 0.0
	_turn_to(to, delta)
	var reach := WALL_REACH + slime.radius
	if to.length() > reach:
		# Along the inside of the wall towards it, never out through it.
		var next := global_position + to.normalized() * _stride("Running_A", RUN_SPEED) * delta
		var cell := level.world_to_cell(next)
		if level.village_wall.is_inside(cell) and not level.astar.is_point_solid(cell) \
				and Vector2(next.x - defend_post.x, next.z - defend_post.z).length() < POST_ROOM:
			_move_to(Vector3(next.x, 0, next.z))
			return
		play("Idle")
		return
	_blow_cool -= delta
	if _blow_cool > 0.0:
		if not _anim.is_playing() or _current_anim != "1H_Melee_Attack_Chop":
			play("Idle")
		return
	_blow_cool = BLOW_TIME
	_current_anim = "1H_Melee_Attack_Chop"
	_anim.play("1H_Melee_Attack_Chop", 0.1)
	get_tree().create_timer(0.4, false, true).timeout.connect(func():
		if eaten or not is_inside_tree() or slime == null or not is_instance_valid(slime) or slime.dead:
			return
		if slime.global_position.distance_to(global_position) > WALL_REACH + slime.radius + 0.6:
			return
		Sfx.play(self, "hit", -8.0, global_position)
		slime.hit_by_rival(blow(), null))


# --- A slime in the village ----------------------------------------------------

## How often a villager strikes a slime (see blow), and from how near.
const BLOW_TIME := 1.3
const BLOW_REACH := 1.7
## A villager in hiding comes out once no slime is this near the door.
const SAFE_DISTANCE := 12.0
## A fighter gives up a slime that gets this far away (CALL_REACH when
## the village was called to arms).
const GIVE_UP := 14.0
## The women and the child who answer the call to arms all the same: the
## priestess (she heals, see VillageArms), the guild master and Pip (he
## throws knives).
const FIGHTING_SHELTERERS := ["O", "G", "7"]
## The villagers' levels: the guard, the guild master and the smith at the
## top, the mages and the priestess close behind, the women and the child
## at the bottom. Zarek the wandering merchant (level 50) is a mage far above
## them all: 250 life and spells that cost a slime dozens of points.
const LEVELS := {"4": 20, "G": 20, "1": 18, "O": 18, "0": 17, "K": 16, "3": 16, "S": 16, "8": 15, "%": 50,
	"Y": 12, "5": 12, "Z": 12, "M": 12, "2": 11, "6": 11, "9": 11, "7": 10}
const DEFAULT_LEVEL := 12
## Townsfolk are made to put up a real fight against a slime of level 20 and
## more (a Blob of about 200 life and 22 damage a blow, every 1.5 seconds):
## a fighter has LIFE_PER_LEVEL life for each level (the guard 100, so five
## blows fell even him) and strikes for 1 + level / BLOW_DIVISOR (the guard
## 11). One alone is beaten, but not before he has taken a third of its life;
## three of them bring it down, and one of them may fall.
const LIFE_PER_LEVEL := 5
const BLOW_DIVISOR := 2
const HEALERS := VillageArms.HEALERS
## How much the priestess heals, how often and how far she reaches. The
## hero is mended too, by HERO_HEAL (his life is counted in smaller steps).
const HEAL := 8
const HERO_HEAL := 3
const HEAL_TIME := 3.0
const HEAL_REACH := 9.0
var _reach := GIVE_UP
var _fight_path: Array[Vector3] = []
var _fight_repath := 0.0
var _heal_cool := 0.0


## The herald (or the guard) calls the village to arms (see VillageAlarm).
func call_to_arms(text: String) -> void:
	say(text, Vector3.INF, 6.0)
	_current_anim = "Cheer"
	_anim.play("Cheer", 0.2)


## The women and the children, who run indoors from a slime while the
## men, the mages and the priestess (see brave) take up arms.
func shelters() -> bool:
	if role in FIGHTING_SHELTERERS:
		return false
	return _info.get("sex", "") == "female" or float(_info.get("scale", 1.0)) < 0.9


## How strong a villager is (10 to 20, see LEVELS): their life against a
## slime (max_life, LIFE_PER_LEVEL a level) and how hard they strike one (blow).
func fight_level() -> int:
	return int(LEVELS.get(role, DEFAULT_LEVEL))


func max_life() -> int:
	return fight_level() * LIFE_PER_LEVEL


func blow() -> int:
	return 1 + fight_level() / BLOW_DIVISOR


## Townsfolk have no attributes of their own, so each starts at the hero's
## 10 (Training) and the strong and the wise are better at it.
const BASE_ATTRIBUTE := 10
const STRONG_ROLES := ["4", "S", "G", "1"]
const WISE_ROLES := ["K", "O", "0"]
const ATTRIBUTE_GIFT := 5
## After a breach (see VillageAlarm) each fighter keeps or loses their nerve.
var shaken := false


func strength() -> int:
	return BASE_ATTRIBUTE + (ATTRIBUTE_GIFT if role in STRONG_ROLES else 0)


func intuition() -> int:
	return BASE_ATTRIBUTE + (ATTRIBUTE_GIFT if role in WISE_ROLES else 0)


func intelligence() -> int:
	return BASE_ATTRIBUTE + (ATTRIBUTE_GIFT if role in WISE_ROLES else 0)


## The nerve test when the wall breaks: strength + intuition + intelligence +
## level. A d100 at or below it holds.
func nerve() -> int:
	return strength() + intuition() + intelligence() + fight_level()


## Rolls a d100 against nerve() (`roll` fixes it for tests). Returns whether they hold.
func test_nerve(roll := -1) -> bool:
	if roll < 0:
		roll = _rng.randi_range(1, 100)
	shaken = roll > nerve()
	say(Lang.t("Ich halte stand!") if not shaken else Lang.t("Das ist zu viel! Weg hier!"))
	return not shaken


## The priestess mends the hurt in her reach (see _fight).
func heals() -> bool:
	return role in HEALERS


## A slime is after them (see Enemy.snack), or the village is called to
## arms (`called`, see VillageAlarm): the brave draw a blade and fight, the
## rest run into the nearest house until it is gone.
func alarm(slime: Enemy, called := false) -> void:
	if eaten or at_home or slime == null or not is_instance_valid(slime) or slime.dead:
		return
	# A slime sniffing at a defender over the wall does not scare them off their post; only the
	# call to arms after a breach (`called`) does.
	if defends() and not called:
		return
	if (threat == slime or not brave) and _task in ["fight", "hide"] or (_task == "walk" and get_meta("then", "") == "hide"):
		return
	# Too big for anyone in the village: all run indoors.
	var too_big := VillageAlarm.too_big(slime) and VillageArms.style(role) != "cast"
	if too_big and _task == "hide":
		return
	_reach = VillageAlarm.CALL_REACH if called else GIVE_UP
	mend_brick = null
	defend_post = Vector3.INF
	_fight_path.clear()
	_fight_repath = 0.0
	threat = slime
	leave_chat()
	_listen_to = Vector3.INF
	if brave and not too_big and not shaken:
		_draw_blade(true)
		say(Lang.t("Weg mit dir, Schleim!"))
		_task = "fight"
		_blow_cool = 0.6
	else:
		_draw_blade(false)
		say(Lang.t("Hilfe! Ein Schleim!"))
		_walk_to(_house_door(), RUN_SPEED, "hide")


## The danger is over (the slime fell, went off, or swallowed them).
func calm_down() -> void:
	threat = null
	_sheathe_later()
	if not at_home:
		_start("idle", _rng.randf_range(0.5, 2.0))


## The blade goes back after SHEATHE_DELAY (see _physics_process).
func _sheathe_later() -> void:
	if drawn():
		_sheathe_in = SHEATHE_DELAY


## Whether a blade is out of its sheath right now.
func drawn() -> bool:
	var hand := _model.find_child("handslot_r", true, false) if _model != null else null
	if hand == null:
		return false
	var blade := hand.get_node_or_null("SlimeBlade")
	return blade != null and not blade.is_queued_for_deletion()


func _draw_blade(on: bool) -> void:
	_sheathe_in = -1.0
	# The priestess keeps her staff and strikes no blow; the smith fights
	# with the hammer already in his hand.
	if heals() or VillageArms.weapon(role) == VillageArms.HAMMER:
		return
	var hand := _model.find_child("handslot_r", true, false) if _model != null else null
	if hand == null:
		return
	var old := hand.get_node_or_null("SlimeBlade")
	if old:
		# Out of the tree at once, so the new blade can take its name.
		hand.remove_child(old)
		old.queue_free()
	# The tool in that hand (a hammer, a mug) is put away meanwhile.
	for c in hand.get_children():
		if c is Node3D and c != old:
			if on and (c as Node3D).visible:
				c.set_meta("put_away", true)
				(c as Node3D).visible = false
			elif not on and c.has_meta("put_away"):
				c.remove_meta("put_away")
				(c as Node3D).visible = true
	if on:
		VillageArms.arm(hand, role)


## Fights the slime: up to it, then a blow every BLOW_TIME (which may leave
## them under its goo, see SlimeCoat). The priestess first mends whoever
## near her a slime has hurt.
func _fight(delta: float) -> void:
	if threat == null or not is_instance_valid(threat) or threat.dead \
			or threat.global_position.distance_to(global_position) > _reach:
		calm_down()
		return
	if heals():
		_support(delta)
		return
	var to := threat.global_position - global_position
	to.y = 0.0
	_turn_to(to, delta)
	var throws := VillageArms.style(role) == "throw"
	var casts := VillageArms.style(role) == "cast"
	var reach := VillageArms.CAST_RANGE if casts else VillageArms.THROW_RANGE if throws else BLOW_REACH + threat.radius
	if casts and to.length() < VillageArms.CAST_KEEP_AWAY:
		# The mage steps back from a slime that gets too close.
		var back := -to.normalized() * _stride("Running_A", RUN_SPEED) * delta
		_move_to(global_position + back)
		_turn_to(to, delta)
	if casts and to.length() > reach and _past_the_leash():
		# Out of range and he will not leave his wagon: let it go.
		calm_down()
		return
	if to.length() > reach or ((throws or casts) and not level.has_line_of_sight(global_position, threat.global_position)):
		# Round the houses on the village's ways when it is further off.
		_fight_repath -= delta
		if _fight_repath <= 0.0:
			_fight_repath = 1.0
			_fight_path.clear()
			if not level.has_line_of_sight(global_position, threat.global_position):
				for c in level.grid_path(level.world_to_cell(global_position), level.world_to_cell(threat.global_position)).slice(1, -1):
					_fight_path.append(level.cell_to_world(c))
		var aim := threat.global_position
		while not _fight_path.is_empty() and Vector2(_fight_path[0].x - global_position.x, _fight_path[0].z - global_position.z).length() < 0.3:
			_fight_path.pop_front()
		if not _fight_path.is_empty():
			aim = _fight_path[0]
		var step := aim - global_position
		step.y = 0.0
		var walked := _stride("Running_A", RUN_SPEED)
		var room := step.length() if not _fight_path.is_empty() else maxf(to.length() - reach + 0.1, 0.0)
		_move_to(global_position + step.normalized() * minf(walked * delta, room))
		_turn_to(step, delta)
		return
	_blow_cool -= delta
	if _blow_cool > 0.0:
		if not _anim.is_playing() or _current_anim != "1H_Melee_Attack_Chop":
			play("Idle")
		return
	if casts:
		_cast_spell()
		return
	if throws:
		_throw_knife()
		return
	_blow_cool = BLOW_TIME
	_current_anim = "1H_Melee_Attack_Chop"
	_anim.play("1H_Melee_Attack_Chop", 0.1)
	var slime := threat
	get_tree().create_timer(0.4, false, true).timeout.connect(func():
		if eaten or not is_inside_tree() or slime == null or not is_instance_valid(slime) or slime.dead:
			return
		if slime.global_position.distance_to(global_position) > BLOW_REACH + slime.radius + 0.6:
			return
		Sfx.play(self, "hit", -8.0, global_position)
		slime.hit_by_rival(blow(), null)
		if SlimeCoat.sticks(slime):
			SlimeGrowth.goo_for_a_while(self, slime.slime_colour()))


var _casts := 0


## Whether the mage is as far from his wagon (his pitch, see home) as he goes.
func _past_the_leash() -> bool:
	var post := level.cell_to_world(home)
	return Vector2(global_position.x - post.x, global_position.z - post.z).length() >= VillageArms.CAST_LEASH


## Zarek's spell at the slime he fights: an arcane bolt, every third time a
## fireball (see VillageArms). They fly as magic shots with their own glow and
## the game's magic sound, and cost the slime a multiple of his blow.
func _cast_spell() -> void:
	_blow_cool = VillageArms.CAST_TIME
	_casts += 1
	var fiery := _casts % VillageArms.CAST_FIRE_EVERY == 0
	_current_anim = "Spellcast_Shoot"
	_anim.play("Spellcast_Shoot", 0.1)
	say(Lang.t("Feuerball!") if fiery else Lang.t("Arkanblitz!"), Vector3.INF, 1.5)
	var slime := threat
	get_tree().create_timer(0.3, false, true).timeout.connect(func():
		if eaten or not is_inside_tree() or slime == null or not is_instance_valid(slime) or slime.dead:
			return
		Sfx.play(self, "magic", -2.0, global_position, 0.8 if fiery else 1.0)
		var origin := global_position + Vector3(0, 1.4, 0)
		var shot := Projectile.spawn(level, origin, slime.global_position + Vector3(0, 1.2, 0) - origin, false, true, fiery)
		shot.damage = blow() * VillageArms.BOLT_FACTOR
		shot.fire_damage = blow() * VillageArms.FIRE_FACTOR
		shot.foe = slime
		shot.at_rival = true)


## Zarek goes for every slime he sees, not only for one that goes for him
## (see alarm): a level 50 mage does not wait to be bitten.
func _hunt_slimes(delta: float) -> void:
	if VillageArms.style(role) != "cast" or threat != null or eaten or at_home or not visible or _task in ["fight", "hide"]:
		return
	_calm_check -= delta
	if _calm_check > 0.0:
		return
	_calm_check = 0.5
	var best: Enemy = null
	var best_d := VillageArms.CAST_HUNT
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead or not e.is_inside_tree() or not SlimeGrowth.grows(e.kind):
			continue
		var d: float = e.global_position.distance_to(global_position)
		var post := level.cell_to_world(home)
		if Vector2(e.global_position.x - post.x, e.global_position.z - post.z).length() > VillageArms.CAST_HUNT:
			continue
		if d < best_d and level.has_line_of_sight(global_position, e.global_position):
			best = e
			best_d = d
	if best != null:
		alarm(best, true)


## Pip's throw: a knife at the slime, then a pause (see VillageArms).
func _throw_knife() -> void:
	_blow_cool = VillageArms.THROW_TIME
	_current_anim = "Throw"
	_anim.play("Throw", 0.1)
	var slime := threat
	get_tree().create_timer(0.3, false, true).timeout.connect(func():
		if eaten or not is_inside_tree() or slime == null or not is_instance_valid(slime) or slime.dead:
			return
		var origin := global_position + Vector3(0, 1.0, 0)
		Sfx.play(self, "swing", -8.0, global_position)
		Projectile.village_knife(level, origin, slime.global_position - origin, slime, blow() + VillageArms.KNIFE_BONUS))


## The priestess strikes no blow: she mends whoever is hurt in her reach
## and otherwise stays near the slime, within SUPPORT_DISTANCE of it.
func _support(delta: float) -> void:
	_heal_cool -= delta
	if _heal_cool <= 0.0 and _heal_someone():
		_heal_cool = HEAL_TIME
		return
	var to := threat.global_position - global_position
	to.y = 0.0
	_turn_to(to, delta)
	if to.length() > VillageArms.SUPPORT_DISTANCE:
		var step := to.normalized() * _stride("Running_A", RUN_SPEED) * delta
		_move_to(global_position + step)
	elif not _anim.is_playing() or _current_anim != "Spellcast_Raise":
		play("Idle")


## The priestess heals the most hurt villager within HEAL_REACH (herself
## too), and the hero when no villager is hurt. Returns whether there was
## anyone to heal.
func _heal_someone() -> bool:
	var best: Villager = null
	var best_lost := 0
	for v in level.villagers:
		if v.eaten or v.at_home or not v.has_meta("slime_life"):
			continue
		if v.global_position.distance_to(global_position) > HEAL_REACH:
			continue
		var lost: int = v.max_life() - int(v.get_meta("slime_life"))
		if lost > best_lost:
			best = v
			best_lost = lost
	if best == null:
		return _heal_hero()
	var life := mini(best.max_life(), int(best.get_meta("slime_life")) + HEAL)
	if life >= best.max_life():
		best.remove_meta("slime_life")
	else:
		best.set_meta("slime_life", life)
	_current_anim = "Spellcast_Raise"
	_anim.play("Spellcast_Raise", 0.15)
	_turn_to(best.global_position - global_position, 1.0)
	Effects.head_text(level, best, best.tag_height(), "+%d" % mini(HEAL, best_lost), Color(0.5, 1.0, 0.55))
	best.add_child(Effects.make_sparkles(Color(1.0, 0.95, 0.6), true))
	Sfx.play(self, "magic", -10.0, global_position, 1.3)
	return true


## The hero, if hurt and within HEAL_REACH, is mended by HERO_HEAL.
func _heal_hero() -> bool:
	var hero: Player = level.player
	if hero == null or hero.dead or hero.hp >= hero.max_hp \
			or hero.global_position.distance_to(global_position) > HEAL_REACH:
		return false
	var before := hero.hp
	hero.hp = mini(hero.max_hp, hero.hp + HERO_HEAL)
	_current_anim = "Spellcast_Raise"
	_anim.play("Spellcast_Raise", 0.15)
	_turn_to(hero.global_position - global_position, 1.0)
	Effects.head_text(level, hero, 2.2, "+%d" % (hero.hp - before), Color(0.5, 1.0, 0.55))
	hero.add_child(Effects.make_sparkles(Color(1.0, 0.95, 0.6), true))
	Sfx.play(self, "magic", -10.0, global_position, 1.3)
	return true


var _fire_cool := 0.0


## Aldo and Odo, the village's mages, hurl a fireball at the nearest monster
## in sight that can ignite (see Ignition). Aldo's hit far harder.
func _cast_fireball(delta: float) -> void:
	_fire_cool = maxf(0.0, _fire_cool - delta)
	if _fire_cool > 0.0 or not Ignition.VILLAGE_MAGES.has(role) or eaten or at_home or not visible or _task == "hide":
		return
	var best: Enemy = null
	var best_d := Ignition.VILLAGE_RANGE
	for e in level.enemies:
		if not is_instance_valid(e) or not Ignition.can_ignite(e) or e.is_friend():
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d and level.has_line_of_sight(global_position, e.global_position):
			best = e
			best_d = d
	if best == null:
		return
	_fire_cool = Ignition.VILLAGE_COOL
	var aim := best.global_position - global_position
	_turn_to(aim, 1.0)
	_current_anim = "Spellcast_Shoot"
	_anim.play("Spellcast_Shoot", 0.1)
	Sfx.play(self, "magic", -4.0, global_position)
	var origin := global_position + Vector3(0, 1.4, 0)
	var shot := Projectile.spawn(level, origin, best.global_position + Vector3(0, 1.2, 0) - origin, false, true, true)
	shot.fire_damage = int(Ignition.VILLAGE_MAGES[role])
	shot.foe = best
	shot.at_rival = true


## Hiding indoors: out again once no slime is near the door.
func _hide(delta: float) -> void:
	_calm_check -= delta
	if _calm_check > 0.0:
		return
	_calm_check = 1.0
	# Called indoors by the herald: out only at the all-clear.
	if level.village_alarm.raised:
		return
	for e in level.enemies:
		if is_instance_valid(e) and not e.dead and SlimeGrowth.grows(e.kind) \
				and e.global_position.distance_to(global_position) < SAFE_DISTANCE:
			return
	threat = null
	_hide_inside(false)
	if night and goes_to_bed():
		_start("home", 10.0)
		_hide_inside(true)
	else:
		_start("idle", _rng.randf_range(0.5, 2.0))


## What comes after the current task: mostly back to work, now and then a
## walk somewhere in the village.
func _next_task() -> void:
	if night and goes_to_bed():
		if _task == "home":
			_start("home", 10.0)
		else:
			_walk_to(_house_door(), WALK_SPEED * 1.15, "home")
		return
	match _info.plan:
		"stay", "shop":
			if level.world_to_cell(global_position) != home:
				_walk_to(level.cell_to_world(home), WALK_SPEED, "work")
			else:
				_start("work", 6.0)
		"work", "sit":
			if _task in ["work", "sit"] and _rng.randf() < 0.35:
				_walk_to(_errand(), WALK_SPEED, "idle")
			elif level.world_to_cell(global_position) != home:
				_walk_to(level.cell_to_world(home), WALK_SPEED, "sit" if _info.plan == "sit" else "work")
			else:
				_start("sit" if _info.plan == "sit" else "work", _rng.randf_range(12.0, 25.0))
		"patrol":
			if _task == "walk":
				_start("idle", _rng.randf_range(3.0, 6.0))
			elif role == "4" and GuardWatch.goes_to_gate(level, _rng.randf()):
				# The slimes come from the pond beyond the west gate (see GuardWatch).
				_walk_to(GuardWatch.post(level), WALK_SPEED, "watch")
			else:
				_walk_to(_nearby(9), WALK_SPEED, "idle")
		"stroll":
			if _task == "walk":
				_start("work", _rng.randf_range(4.0, 9.0))
			else:
				_walk_to(_nearby(4), WALK_SPEED * 0.7, "work")
		"wander":
			if _task == "walk" or _rng.randf() < 0.5:
				_start("work" if _rng.randf() < 0.4 else "idle", _rng.randf_range(1.5, 4.0))
			elif _info.has("pal") and _rng.randf() < 0.3 and KidPlay.fine_day(self) and _play_spot() != Vector3.INF:
				# Off to play with the friend: a run to their side, then a game (see KidPlay).
				_walk_to(_play_spot(), RUN_SPEED, "play")
			elif _info.get("herds", false) and _rng.randf() < 0.45 and VillageFarm.herd_spot(level, role, _rng.randf()) != Vector3.INF:
				# Off to mind the goats and the geese (see VillageFarm).
				_walk_to(VillageFarm.herd_spot(level, role, _rng.randf()), WALK_SPEED * 1.4, "work")
			else:
				_walk_to(_nearby(5), RUN_SPEED, "idle")
		"carry":
			# Between the well and the houses, with a stop at each.
			var at_well := level.world_to_cell(global_position) == home
			if _task == "walk":
				_start("work" if at_well else "idle", _rng.randf_range(2.5, 4.5))
			elif at_well:
				var houses: Array = level.spots.houses
				_walk_to(houses[_rng.randi() % houses.size()] if not houses.is_empty() else _nearby(6), WALK_SPEED, "idle")
			else:
				_walk_to(level.cell_to_world(home), WALK_SPEED, "work")


## A free tile beside the friend (see "pal" in ROLES), or INF when they are
## indoors or not in the village. Open ground only, so nobody plays in a wall.
func _play_spot() -> Vector3:
	for v: Villager in level.villagers:
		if v.role != _info.get("pal", "") or v.at_home or not v.visible:
			continue
		var at := level.world_to_cell(v.global_position)
		for i in 12:
			var c := at + Vector2i(_rng.randi_range(-2, 2), _rng.randi_range(-2, 2))
			if c != at and FarmAnimal.may_stand(level, c) and not _spot_taken(c):
				return level.cell_to_world(c)
	return Vector3.INF


## Somewhere in the village worth a visit: the well, the square, a house.
func _errand() -> Vector3:
	var places: Array = level.spots.well + level.spots.square
	if places.is_empty() or level.world_to_cell(places[0]).distance_to(home) > 18:
		return _nearby(5)
	return places[_rng.randi() % places.size()]


## A free tile within a few tiles of home, never right at the spot of
## someone who keeps to it (see keeps_spot).
func _nearby(radius: int) -> Vector3:
	for i in 20:
		var c := home + Vector2i(_rng.randi_range(-radius, radius), _rng.randi_range(-radius, radius))
		if level.is_open(c) and not _spot_taken(c):
			return level.cell_to_world(c)
	return level.cell_to_world(home)


## Whether this villager stands their ground: a shopkeeper, the elder, the
## herald. Others walk round them and are pushed off their spot, never the
## other way round, so their shop or word is always there to bump into.
func keeps_spot() -> bool:
	return _info.plan in ["shop", "stay"]


## Whether a tile is next to the spot of someone else who keeps to it.
func _spot_taken(c: Vector2i) -> bool:
	for o: Villager in level.people():
		if o != self and o.keeps_spot() and maxi(absi(o.home.x - c.x), absi(o.home.y - c.y)) <= 1:
			return true
	return false


## How much room this villager leaves the other one.
func _space_for(o: Villager) -> float:
	return PERSONAL_SPACE if o.keeps_spot() else PASSING_SPACE


## Steps out of the way of everyone this villager has to make room for: all
## who keep their spot, and, a little, anyone else walking about. One who
## keeps their own spot never steps aside. Asleep at home, nobody is in the
## way.
func _keep_apart() -> void:
	if at_home or keeps_spot():
		return
	for o: Villager in level.people():
		if o == self or o.at_home:
			continue
		var away := global_position - o.global_position
		away.y = 0.0
		var room := _space_for(o)
		if away.length() >= room:
			continue
		if away.length() < 0.01:
			away = Vector3(cos(rotation.y), 0, sin(rotation.y))
		# Two walking about share the step; from a shopkeeper the walker
		# steps away all by himself.
		var share := 1.0 if o.keeps_spot() else 0.5
		_move_to(global_position + away.normalized() * (room - away.length()) * share)


func _walk_to(target: Vector3, speed: float, then: String) -> void:
	_path.clear()
	var from := level.world_to_cell(global_position)
	for c in level.grid_path(from, level.world_to_cell(target)).slice(1):
		_path.append(level.cell_to_world(c) + Vector3(_rng.randf_range(-WalkRules.JITTER, WalkRules.JITTER), 0, _rng.randf_range(-WalkRules.JITTER, WalkRules.JITTER)))
	if _path.is_empty():
		_start(then, 3.0)
		return
	_speed = speed
	_task = "walk"
	set_meta("then", then)


# --- Every frame --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if level == null or level.player == null:
		return
	_lift_onto_toes(delta)
	if _sheathe_in >= 0.0:
		_sheathe_in -= delta
		if _sheathe_in < 0.0:
			_draw_blade(false)
	bump_cool = maxf(0.0, bump_cool - delta)
	_keep_apart()
	_mind_torch(delta)
	station.pos = global_position
	station.cell = level.world_to_cell(global_position)
	_update_bubble(delta)
	var hero: Node3D = level.player
	# Play ends when anything else comes first: a task of another kind, or a word with the hero.
	if _kid != null and _kid.active and (_task != "play" or _bubble_time > 0.0):
		_kid.stop()
		if _task == "play":
			_start("idle", 1.5)
	_cast_fireball(delta)
	_hunt_slimes(delta)
	if _bubble_time > 0.0 and _look_at != Vector3.INF:
		_turn_to(_look_at - global_position, delta)
		if _task != "sit" and not _chat_sitting:
			play("Idle")
		return
	match _task:
		"home":
			pass
		"fight":
			_fight(delta)
			return
		"hide":
			_hide(delta)
			return
		"walk":
			_walk(delta, hero)
		"mend":
			_mend(delta)
		"defend":
			_defend(delta)
		"watch":
			_watch(delta)
		"work", "sit", "idle":
			_do(_task, delta)
		"listen":
			_turn_to(_listen_to - global_position, delta)
			play("Idle")
		"feed":
			_feed(delta)
		"play":
			_play(delta)
		"chat":
			if chat_partner and is_instance_valid(chat_partner):
				_turn_to(chat_partner.global_position - global_position, delta)
			play(_info.work if _chat_sitting else "Idle")
	_task_time -= delta
	if _task != "walk" and _task_time <= 0.0:
		if _task == "listen":
			# The news is out: back to the day's work.
			_listen_to = Vector3.INF
			_start("idle", 0.1)
		_next_task()
	if role == "0" and hero.global_position.distance_to(global_position) < 8.0:
		_turn_to(hero.global_position - global_position, delta)


## The children's game (see KidPlay): chasing each other, cartwheels and somersaults.
func _play(delta: float) -> void:
	if _kid == null:
		_kid = KidPlay.new(self)
	if not _kid.active and not _kid.begin():
		_start("idle", _rng.randf_range(2.0, 4.0))
		return
	if not _kid.tick(delta):
		_kid.stop()
		_start("idle", _rng.randf_range(1.5, 3.0))


## The friend started a game and we join in, chased first (see KidPlay.begin).
func join_play(friend: Villager, at: Vector3, time: float) -> void:
	_path.clear()
	if _kid == null:
		_kid = KidPlay.new(self)
	_start("play", time)
	_kid.join(friend, at)


func _walk(delta: float, hero: Node3D) -> void:
	if _path.is_empty():
		var then: String = get_meta("then", "idle")
		var time := _rng.randf_range(2.0, 5.0)
		if then in ["work", "sit"]:
			time = _rng.randf_range(8.0, 16.0)
		elif then == "play":
			time = _rng.randf_range(14.0, 24.0)
		elif then == "listen":
			time = LISTEN_TIME + _rng.randf_range(-2.0, 2.0)
		elif then == "watch":
			time = _rng.randf_range(GuardWatch.STAND_MIN, GuardWatch.STAND_MAX)
		elif then == "chat":
			time = CHAT_WAIT
		_start(then, time)
		return
	# A step that would end inside a shopkeeper is left out: the path goes
	# on from the next one, round them.
	while _path.size() > 1 and _crowds_spot(_path[0]):
		_path.pop_front()
	if _path.size() == 1 and _crowds_spot(_path[0]):
		_path.clear()
		return
	var to := _path[0] - global_position
	to.y = 0.0
	# Polite: wait when the hero stands in the way.
	var ahead := hero.global_position - global_position
	ahead.y = 0.0
	if ahead.length() < 1.6 and to.length() > 0.01 and ahead.normalized().dot(to.normalized()) > 0.3:
		_waiting += delta
		play("Idle")
		if _waiting < MAKE_WAY:
			return
		# Still blocked: go round by trying the walk again later.
		_waiting = 0.0
		_start("idle", 1.5)
		return
	_waiting = 0.0
	var walked := _stride("Running_A" if _speed >= RUN_SPEED else ("Walking_B" if _speed < WALK_SPEED else "Walking_A"), _speed)
	var step := walked * delta
	var target := Vector3(_path[0].x, 0, _path[0].z) if to.length() <= step else global_position + to.normalized() * step
	if blocked_at(target) and not blocked_at(global_position):
		# A gate was shut (or a wall stands) ahead: wait, then find the way again.
		play("Idle")
		_waiting += delta
		if _waiting >= MAKE_WAY:
			_waiting = 0.0
			var goal: Vector3 = _path[_path.size() - 1]
			_walk_to(goal, _speed, get_meta("then", "idle"))
		return
	var before := global_position
	global_position = target
	_stepped = TownsfolkSteps.walk(self, level, _stepped, before.distance_to(target), _speed >= RUN_SPEED)
	if to.length() <= step:
		_path.pop_front()
	_turn_to(to, delta)


## Whether a point is inside a wall brick that stops everyone: a standing wall or a shut gate.
## Called after the footprint pass (see Footprint.settle) moved this villager to a free
## spot: the way on from there is found again.
func footprint_moved() -> void:
	_path.clear()


func blocked_at(point: Vector3) -> bool:
	return WalkRules.blocked_at(level, point)


## Moves to a point unless a wall or a shut gate is there. Returns whether it moved.
func _move_to(point: Vector3) -> bool:
	if blocked_at(point) and not blocked_at(global_position):
		return false
	global_position = Vector3(point.x, global_position.y, point.z)
	return true


## Whether a point is too close to someone else who keeps their spot.
func _crowds_spot(point: Vector3) -> bool:
	for o: Villager in level.people():
		if o != self and o.keeps_spot() and not o.at_home and Vector2(point.x - o.global_position.x, point.z - o.global_position.z).length() < PERSONAL_SPACE:
			return true
	return false


func _do(task: String, delta: float) -> void:
	if task == "idle":
		play("Idle")
		return
	if task == "sit":
		play(_info.work)
		return
	var work: String = _info.work
	if _anim.get_animation(work).loop_mode != Animation.LOOP_NONE:
		play(work)
		return
	if chops() and not _ready_to_chop(delta):
		return
	# One-off moves (a hammer blow, picking something up) again and again,
	# with a breath in between.
	if chops() and _current_anim == work and _bite(delta):
		return
	if _anim.is_playing() and _current_anim == work:
		return
	_work_pause -= delta
	if _current_anim == work:
		play("Idle", 0.2)
		_work_pause = _rng.randf_range(0.3, 1.2) if role in ["1", "3"] else _rng.randf_range(1.5, 3.5)
		return
	if _work_pause > 0.0:
		return
	_current_anim = work
	_anim.play(work, 0.15)
	_bitten = false
	_rebound = false
	# The smith strikes a few times in a row before he takes a breath.
	_blows = _rng.randi_range(1, 3) if smiths() else 0
	# The woodcutter's blow is heard when the blade bites (see _bite).
	if _info.has("sound") and not chops():
		get_tree().create_timer(0.45).timeout.connect(func():
			if is_inside_tree():
				Sfx.play(self, _info.sound, -16.0, global_position, 0.8))


## Gives the woodcutter his trunk (or the smith his anvil): he stands at
## `stand`, faces `face` and the blade or hammer lands where `chips` (placed
## by the caller at BITE_POINT or HAMMER_POINT) throws up its splinters or
## sparks.
func set_chopping(stand: Vector3, face: Vector3, chips: CPUParticles3D) -> void:
	_chop_stand = stand
	_chop_face = face
	_chips = chips


## Whether this villager strikes something of his own: wood on a trunk, or
## iron on an anvil.
func chops() -> bool:
	return _chop_stand != Vector3.INF


## Before a blow: the woodcutter (or smith) steps onto his spot by the trunk
## (or anvil) and turns to it. A swing comes only when he is there; anywhere
## else (his walk home was cut short) he waits, so he never hits the air.
func _ready_to_chop(delta: float) -> bool:
	if _current_anim == _info.work and _anim.is_playing():
		return true
	if level.world_to_cell(global_position) != home:
		play("Idle")
		return false
	var to := _chop_stand - global_position
	to.y = 0.0
	if to.length() > 0.05:
		var step := minf(to.length(), _stride("Walking_B", WALK_SPEED * 0.6) * delta)
		_move_to(global_position + to.normalized() * step)
		_turn_to(to, delta)
		return false
	_turn_to(_chop_face, delta)
	var facing := Vector3(sin(rotation.y), 0, cos(rotation.y))
	if facing.angle_to(_chop_face) > 0.02:
		if _current_anim != _info.work:
			play("Idle")
		return false
	# Squarely on the spot: a blow lands where it was measured.
	rotation.y = atan2(_chop_face.x, _chop_face.z)
	global_position = Vector3(_chop_stand.x, global_position.y, _chop_stand.z)
	return true


## Whether this villager is the smith (his blows ring on the anvil).
func smiths() -> bool:
	return role == "1"


## During a blow: when the blade reaches the trunk it stops there, stuck in
## the wood, chips fly and the chop is heard; a moment later he wrenches the
## axe out and stands back. The smith's hammer stops on the iron only for a
## beat, with sparks and the ring of the anvil, and springs back up (see
## HAMMER_REBOUND). True while the blow is held here.
func _bite(delta: float) -> bool:
	var smith := smiths()
	if not _bitten:
		var at := HAMMER_TIME if smith else BITE_TIME
		if _anim.current_animation_position < at:
			return false
		_bitten = true
		# Exactly on the wood or the iron, not a tick later inside it.
		_anim.seek(at, true)
		_anim.speed_scale = 0.0
		_stuck = HAMMER_HOLD if smith else BITE_HOLD
		if _chips:
			_chips.restart()
		Sfx.play(self, "anvil" if smith else "chop", -14.0 if smith else -12.0, global_position, _rng.randf_range(0.9, 1.1))
		return true
	if _rebound:
		if _anim.current_animation_position > HAMMER_RAISED:
			return true
		if _blows > 0:
			# Down again from up here.
			_blows -= 1
			_rebound = false
			_bitten = false
			_anim.speed_scale = 1.0
			return true
		# The last blow: he lowers the hammer the way he raised it, which
		# keeps it clear of the anvil, and rests.
		if _anim.current_animation_position > HAMMER_LOWERED:
			return true
		play("Idle", 0.1)
		_work_pause = _rng.randf_range(0.4, 1.0)
		return true
	if _stuck <= 0.0:
		return false
	_stuck -= delta
	if _stuck > 0.0:
		return true
	if smith:
		_rebound = true
		_anim.speed_scale = -HAMMER_REBOUND
		return true
	_anim.speed_scale = 1.0
	play("Idle", 0.35)
	_work_pause = _rng.randf_range(0.5, 1.3)
	return true


func _turn_to(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length() < 0.01:
		return
	WalkRules.turn(self, direction, delta)


# --- Night -------------------------------------------------------------------

## Whether this villager sleeps at night (see NIGHT_OWLS).
func goes_to_bed() -> bool:
	return not role in NIGHT_OWLS and not works_late()


## The stonemason stays up (or gets up) at night while the wall has a hurt
## brick he may safely work on: no alarm, no shut gates, no slime near it.
func works_late() -> bool:
	if role != "S" or level == null or level.village_wall == null:
		return false
	return mend_brick != null or level.village_wall.job(level) != null


## Night falls or the day breaks. At nightfall the villager walks to the
## nearest house and goes in; in the morning they step out of the door and
## go back to their day. `at_once` settles it on the spot (a game loaded at
## night finds the village already asleep).
func set_night(on: bool, at_once := false) -> void:
	night = on
	if role in NIGHT_OWLS or (on and works_late()):
		return
	if on:
		_listen_to = Vector3.INF
		_bubble_time = 0.0
		if at_once:
			global_position = _house_door()
			_settling = true
			_start("home", 10.0)
			_settling = false
		elif _task != "home":
			_walk_to(_house_door(), WALK_SPEED * 1.15, "home")
	elif at_home:
		_hide_inside(false, true)
		_start("idle", _rng.randf_range(0.5, 4.0))
	elif _task == "walk" and get_meta("then", "") == "home":
		_start("idle", 0.5)


## Whether the villager walks about with a torch right now: at night, out
## in the street, unless they keep to one lit spot (UNLIT_PLANS). Anyone
## walking home carries one all the same.
func carries_torch() -> bool:
	if not night or at_home or not visible:
		return false
	return _task == "walk" or not _info.plan in UNLIT_PLANS


## Lights the torch, puts it out, and lets it flicker while it burns.
func _mind_torch(delta: float) -> void:
	var on := carries_torch()
	if on and _torch == null:
		_make_torch()
	if _torch == null:
		return
	if _torch.visible != on:
		_torch.visible = on
		_torch_light.visible = on
		for item in _torch_hidden:
			item.visible = not on
	if on:
		_torch_time += delta
		_torch_light.light_energy = TORCH_ENERGY * (0.86 + 0.14 * sin(_torch_time * 11.0) * sin(_torch_time * 6.7))


## A stick with a flame on its tip in the left hand (what the hand holds by
## day, a shield or a book, is put away meanwhile), and its light, hung on
## the body so it does not swing about. The same flame as the lanterns', so
## no shader is new to the renderer (see LevelWarmup).
func _make_torch() -> void:
	var size: float = _info.get("scale", 1.0)
	var hand: Node3D = _model.find_child("handslot_l", true, false)
	_torch = Node3D.new()
	_torch.name = "Torch"
	if hand:
		for item in hand.get_children():
			if item is Node3D and item.visible:
				_torch_hidden.append(item)
		hand.add_child(_torch)
	else:
		_torch.position = Vector3(0.45, 1.3, 0.3) * size
		add_child(_torch)
	var stick := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.045
	rod.bottom_radius = 0.03
	rod.height = 0.6
	stick.mesh = rod
	stick.material_override = _torch_wood()
	stick.position = Vector3(0, 0.15, 0)
	_torch.add_child(stick)
	var flame := Effects.make_flame()
	flame.scale = Vector3.ONE * 0.55
	flame.position = Vector3(0, 0.5, 0)
	_torch.add_child(flame)
	_torch_light = OmniLight3D.new()
	_torch_light.light_color = TORCH_COLOR
	_torch_light.light_energy = TORCH_ENERGY
	_torch_light.omni_range = TORCH_RANGE
	_torch_light.omni_attenuation = 1.4
	_torch_light.position = Vector3(0.4, 2.3, 0.4) * size
	add_child(_torch_light)
	_torch.visible = false
	_torch_light.visible = false


## One plain wooden material for every villager's torch.
static func _torch_wood() -> StandardMaterial3D:
	if _wood == null:
		_wood = StandardMaterial3D.new()
		_wood.albedo_color = Color(0.32, 0.2, 0.11)
	return _wood


## The door of the house the villager sleeps in (see _house_door).
func house_door() -> Vector3:
	return _house_door()


## The door of the house nearest to the villager's own spot.
func _house_door() -> Vector3:
	var houses: Array = level.spots.houses
	var at := level.cell_to_world(home)
	var best := at
	var best_d := INF
	for h: Vector3 in houses:
		var d := at.distance_to(h)
		if d < best_d:
			best_d = d
			best = h
	return best


## In through the door (gone from the street) or back out of it. With
## `at_the_door` the door of the house swings open for them (see HouseDoor), and
## a villager going in is gone from the street only once it is open.
func _hide_inside(inside: bool, at_the_door := false) -> void:
	if eaten and not inside:
		return # Inside a slime, not at home: morning does not bring them out.
	at_home = inside
	if at_the_door and not _settling and is_inside_tree() and level != null and level.swing_door_near(global_position):
		if inside:
			get_tree().create_timer(HouseDoor.OPEN_TIME).timeout.connect(func():
				if at_home:
					visible = false)
		else:
			visible = true
	else:
		visible = not inside
	if inside:
		_layer = collision_layer if collision_layer != 0 else _layer
		collision_layer = 0
	else:
		collision_layer = _layer
	if station:
		station.used = inside


# --- Gathering on the square -------------------------------------------------

## Who drops their work to hear the herald: not the shopkeeper at her
## stall, the elder or the woodcutter out in the woods.
func comes_to_listen() -> bool:
	return not night and _info.plan in ["work", "sit", "patrol", "stroll", "wander", "carry"] and role != "3" and _task != "listen"


func gather_at(spot: Vector3, speaker: Vector3) -> void:
	_listen_to = speaker
	_walk_to(spot, WALK_SPEED * 1.2, "listen")


## The herald's call: the next piece of news, arm raised.
func proclaim() -> void:
	say(Lang.t(NEWS[_news % NEWS.size()]), Vector3.INF, 7.0)
	_news += 1
	_current_anim = "Cheer"
	_anim.play("Cheer", 0.2)


# --- Talking ------------------------------------------------------------------

## The hero ran into us: say the next line.
func talk(hero: Node3D) -> void:
	var lines: Array = _info.lines
	meet()
	say(Lang.t(lines[_line % lines.size()]), hero.global_position)
	_line += 1


## Whether the hero has talked to this villager before (also in an earlier
## session: the village remembers, see Outdoor.met).
func is_known() -> bool:
	return level != null and level.met.has(role)


## The hero and this villager have spoken: from now on the name stays over
## the head, so the people of the village can be told apart.
func meet() -> void:
	if level:
		level.met[role] = true
	if _name_tag:
		_name_tag.visible = true


## The elder sees the newcomer and hands over the house.
func greet_newcomer(hero: Node3D) -> void:
	_line = 1
	meet()
	say(Lang.t("Willkommen, Fremder! Du kommst aus der alten Gruft? In der Weberzeile steht ein Haus für dich bereit."), hero.global_position, 6.5)


## Shows "!" (a task to offer), "?" (a task to hand in) or nothing ("").
func set_quest_mark(text: String) -> void:
	if _quest_mark == null:
		return
	_quest_mark.text = text
	_quest_mark.visible = text != ""


## The mark over the head right now ("" when none shows).
func quest_mark() -> String:
	return _quest_mark.text if _quest_mark and _quest_mark.visible else ""


## `in_chat`: a line of a chat with another villager (see chat_say); any
## other line breaks off a chat.
func say(text: String, look_at := Vector3.INF, time := SAY_TIME, in_chat := false) -> void:
	if chat_partner != null and not in_chat:
		chat_broken = true
	singing = false
	# Whoever else is talking right beside us stops, or both bubbles would
	# cover each other and neither could be read.
	for other in _neighbours():
		other.hush()
	_bubble.show_line(display_name, text, true)
	Events.say(display_name, text, global_position)
	_bubble_time = time
	_bubble_hold = minf(time, MIN_SAY_TIME)
	_look_at = look_at
	if _task == "walk":
		_start("idle", 0.5)


## How high over our feet the name tag floats (metres): the song sheet's tail
## points just above it (see SongSheet).
func tag_height() -> float:
	return _name_tag.position.y if _name_tag else 2.75


## A line of a drinking song (see DrinkingSongs): said like any other, and
## we stay in our seat until it is sung.
func sing(text: String, time: float) -> void:
	say(text, Vector3.INF, time)
	# The song sheet already shows the words; a speech bubble over it would
	# say them twice. The bubble's text stays as the line being sung.
	_bubble.hide_line(true)
	singing = true
	if _task == "sit":
		_task_time = maxf(_task_time, time + 1.0)


## Whether the current line has not been shown long enough to be read: the
## hero running into us again gets no new line yet.
func is_busy_talking() -> bool:
	return _bubble_hold > 0.0 and _bubble_time > 0.0


## Whether a line shows over our head right now.
func is_talking() -> bool:
	return _bubble_time > 0.0


## Breaks off the line we are saying: the bubble goes at once, without a fade,
## so it never shows behind the next one.
func hush() -> void:
	_bubble_time = 0.0
	_bubble_hold = 0.0
	_bubble.hide_line(true)
	_look_at = Vector3.INF


## Someone else close enough that their bubble would cover ours who is
## talking right now (or null). Chats and other lines that can wait hold
## back until they are done, so the lines come one after another.
func talker_near(ignore: Villager = null) -> Villager:
	for other in _neighbours():
		if other != ignore and other.is_talking():
			return other
	return null


## The other villagers whose bubbles would lie over ours.
func _neighbours() -> Array:
	var near := []
	if level == null:
		return near
	var everyone: Array = level.villagers.duplicate()
	if level.wanderer and not everyone.has(level.wanderer):
		everyone.append(level.wanderer)
	for other in everyone:
		if other == self or not is_instance_valid(other) or not other.visible:
			continue
		var d: Vector3 = other.global_position - global_position
		d.y = 0.0
		if d.length() < BUBBLE_ROOM:
			near.append(other)
	return near


func _update_bubble(delta: float) -> void:
	_bubble_time = maxf(0.0, _bubble_time - delta)
	_bubble_hold = maxf(0.0, _bubble_hold - delta)
	# The line shows in a speech bubble over the head (and is also written
	# into the event log, see Events.say). When it runs out the bubble fades.
	if _bubble_time <= 0.0 and _bubble.is_shown():
		_bubble.hide_line()
	# The bubble takes the place of the quest mark while we talk.
	if _name_tag and _name_tag.visible:
		_name_tag.modulate.a = 1.0
		_name_tag.outline_modulate.a = 0.85
	# The quest mark bobs gently while it shows.
	if _quest_mark and _quest_mark.visible:
		var shown := 0.0 if _bubble_time > 0.0 else 1.0
		_quest_mark.modulate.a = shown
		_quest_mark.outline_modulate.a = 0.9 * shown
		_mark_time += delta
		_quest_mark.position.y = _mark_base + 0.08 * sin(_mark_time * 3.0)
	if _bubble_time <= 0.0:
		_look_at = Vector3.INF


# --- Feeding the birds (see VillageBirds) ---------------------------------------

## Whether we could stop to feed the birds now: awake, out in the street,
## idling (after an errand, between rounds), not talking or listening, and
## not one who keeps to a shop or a spot.
func can_feed_birds() -> bool:
	if chat_partner != null or at_home or not visible or role == "%" or singing or night:
		return false
	return _task == "idle" and _bubble_time <= 0.0 and _listen_to == Vector3.INF and not keeps_spot()


## Stops for `time` seconds to throw a few handfuls of seed on the ground
## ahead, calls the birds and stands watching them. Returns where the seed
## lands (world space, on the ground).
func feed_birds(time: float) -> Vector3:
	_start("feed", time)
	_tosses = SEED_TOSSES
	_toss_clock = -0.3
	_tossed = false
	var ahead := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	_seed_spot = Vector3(global_position.x, 0.0, global_position.z) + ahead * SEED_AHEAD
	Events.say(display_name, Lang.t(SEED_CALLS[_rng.randi() % SEED_CALLS.size()]), global_position)
	return _seed_spot


## Whether we are feeding the birds right now.
func is_feeding() -> bool:
	return _task == "feed"


## Throws the handfuls one after another, then stands still and watches.
func _feed(delta: float) -> void:
	_turn_to(_seed_spot - global_position, delta)
	if _tosses <= 0:
		play("Idle")
		return
	_toss_clock += delta
	if _current_anim == "Throw":
		if not _tossed and _toss_clock >= SEED_RELEASE:
			_tossed = true
			_tosses -= 1
			seeds_tossed.emit(hand_at(), _seed_spot)
		if _toss_clock >= SEED_RELEASE and not _anim.is_playing():
			play("Idle", 0.2)
			_toss_clock = -_rng.randf_range(SEED_PAUSE.x, SEED_PAUSE.y)
		return
	if _toss_clock >= 0.0:
		_current_anim = "Throw"
		_anim.play("Throw", 0.15)
		_toss_clock = 0.0
		_tossed = false


func _bones() -> Skeleton3D:
	if _skeleton == null and _model:
		var found := _model.find_children("*", "Skeleton3D", true, false)
		if not found.is_empty():
			_skeleton = found[0]
	return _skeleton


## The throwing hand, in world space.
func hand_at() -> Vector3:
	var bones := _bones()
	if bones == null:
		return global_position + Vector3.UP * 1.2
	return (bones.global_transform * bones.get_bone_global_pose(bones.find_bone("handslot.r"))).origin


## Where a bird can sit on us, in our own space (so it can be drawn with our
## smoothed body): 0 on top of the head (or the hat), 1 on the left shoulder,
## 2 on the right one. The head turns and bobs with the animation, the birds
## with it.
func perch_point(slot: int) -> Vector3:
	var bones := _bones()
	if bones == null:
		return Vector3(0.0, 2.3, 0.0) if slot == 0 else Vector3(0.45 * (1 if slot == 1 else -1), 1.3, 0.0)
	var mine := global_transform.affine_inverse() * bones.global_transform
	if slot == 0:
		return mine * (bones.get_bone_global_pose(bones.find_bone("head")) * Vector3(0.0, _top_of_head(), 0.0))
	var side := 1.0 if slot == 1 else -1.0
	var arm := bones.get_bone_global_pose(bones.find_bone("upperarm.l" if slot == 1 else "upperarm.r")).origin
	# Out on the shoulder, past the edge of the big head.
	return mine * (arm + Vector3(side * PERCH_OUT, PERCH_UP, 0.14))


## How far out and up from the shoulder joint a bird sits (model units).
const PERCH_OUT := 0.46
const PERCH_UP := 0.12


## The top of the head above the head bone (model units): the hat or helmet
## if one shows, else the head itself.
func _top_of_head() -> float:
	if _head_top >= 0.0:
		return _head_top
	var bones := _bones()
	_head_top = 0.96
	if bones == null:
		return _head_top
	var head_y := bones.get_bone_global_rest(bones.find_bone("head")).origin.y
	for mi: MeshInstance3D in bones.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		if String(mi.name).ends_with("_Head"):
			_head_top = maxf(_head_top, mi.get_aabb().end.y - head_y)
			continue
		# A hat, helmet, crest or bun fixed to the head bone: its box in the
		# head's own space (a little below its very top, the tip of a hat,
		# unless the hat is flat on top, like the postmaster's cap).
		var xf := Transform3D.IDENTITY
		var node: Node = mi
		while node != bones and not node is BoneAttachment3D:
			xf = (node as Node3D).transform * xf
			node = node.get_parent()
		if node is BoneAttachment3D and (node as BoneAttachment3D).bone_name == "head":
			_head_top = maxf(_head_top, (xf * mi.get_aabb()).end.y * (1.0 if mi.has_meta("flat_top") else 0.92))
	return _head_top


# --- Chatting with each other (see VillageTalk) ---------------------------------

## Whether we are free for a chat: awake, out in the village, at work or
## idling (not walking somewhere, listening to the herald or talking).
func can_chat() -> bool:
	if chat_partner != null or at_home or not visible or role == "%" or singing:
		return false
	if night and goes_to_bed():
		return false
	return _task in ["work", "idle", "sit"] and _bubble_time <= 0.0 and _listen_to == Vector3.INF


## Whether we may stop for a chat when someone walking bumps into us: out on
## a plain walk of our own (not to a stall, a post, a house, the herald or a
## chat), awake, not saying anything, not afraid or fighting, and not a
## shopkeeper or guard on duty.
func can_bump_chat() -> bool:
	if chat_partner != null or at_home or not visible or role == "%" or singing or night:
		return false
	if bump_cool > 0.0 or keeps_spot() or threat != null or eaten or defends() or shaken:
		return false
	if _task != "walk" or get_meta("then", "") in ["chat", "watch", "defend", "listen", "home", "hide"]:
		return false
	return _bubble_time <= 0.0 and _listen_to == Vector3.INF


## Whether we can speak up on our own about the weather or a fright (see
## VillageWorries): out in the street and awake, walking home too, but not in
## a chat, listening to the herald or saying something already.
func can_remark() -> bool:
	if chat_partner != null or at_home or not visible or role == "%":
		return false
	return not _task in ["home", "listen", "chat"] and _bubble_time <= 0.0


## Starts a chat with `partner`. `walk`: we go over to them (and stop a step
## short, on our side); otherwise we wait where we are. Returns false when
## there is no way over.
func join_chat(partner: Villager, walk: bool) -> bool:
	if walk:
		var at := partner.global_position
		var cells := level.grid_path(level.world_to_cell(global_position), level.world_to_cell(at))
		if cells.is_empty() and level.world_to_cell(global_position) != level.world_to_cell(at):
			return false
		_path.clear()
		# Every tile on the way but our own and theirs, then a spot beside them.
		for c in cells.slice(1, maxi(1, cells.size() - 1)):
			_path.append(level.cell_to_world(c) + Vector3(_rng.randf_range(-WalkRules.JITTER, WalkRules.JITTER), 0, _rng.randf_range(-WalkRules.JITTER, WalkRules.JITTER)))
		var last: Vector3 = _path.back() if not _path.is_empty() else global_position
		var side := last - at
		side.y = 0.0
		if side.length() < 0.1:
			side = Vector3(1, 0, 0)
		_path.append(Vector3(at.x, 0, at.z) + side.normalized() * CHAT_GAP)
		_speed = WALK_SPEED
		_task = "walk"
		set_meta("then", "chat")
		_chat_sitting = false
	else:
		_chat_sitting = _task == "sit"
		_start("chat", CHAT_WAIT)
	chat_partner = partner
	chat_broken = false
	return true


## Stops where we stand and faces `partner`: a bump-chat (see
## VillageTalk.start_bump_chat). The walk is dropped; the day's plan picks up
## again when the chat ends (see leave_chat).
func stand_for_chat(partner: Villager) -> void:
	_path.clear()
	_chat_sitting = false
	_start("chat", CHAT_WAIT)
	chat_partner = partner
	chat_broken = false


## Standing with the partner, ready to talk.
func in_chat_place() -> bool:
	return chat_partner != null and _task == "chat"


## Still on the way to the partner.
func heading_to_chat() -> bool:
	return chat_partner != null and _task == "walk" and get_meta("then", "") == "chat"


## A line of a chat, said to the partner.
func chat_say(text: String, time: float) -> void:
	var at := chat_partner.global_position if chat_partner and is_instance_valid(chat_partner) else Vector3.INF
	say(text, at, time, true)


## The chat is over: back to the day's plan.
func leave_chat() -> void:
	var waiting := _task == "chat" or heading_to_chat()
	chat_partner = null
	chat_broken = false
	bump_cool = BUMP_COOLDOWN
	if waiting:
		_path.clear()
		_start("sit" if _chat_sitting else "idle", _rng.randf_range(1.0, 2.5))
	_chat_sitting = false
