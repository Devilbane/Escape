class_name VillagerJobs
extends RefCounted
## What a villager answers when the hero asks about their work through the chat
## line (see HeroChat). The name over their head is only the plain name; the job
## is told in words. A villager without an entry here (a new one) still answers
## with a generic line built from their full name in Villager.ROLES, so nobody
## stays mute.
##
## Every text is German and has an English entry in scripts/lang/villager_jobs.gd.

## Words that make a line a question about work (lower case, German and English).
const WORDS := ["arbeit", "arbeitest", "beruf", "job", "jobs", "tätigkeit", "was machst du", "was tust du", "was bist du", "womit verdienst", "work", "working", "occupation", "profession", "what do you do", "what are you", "what is your trade"]

## By role letter (see Villager.ROLES): what they say about their work.
const JOBS := {
	"0": "Ich bin der Dorfvorsteher. Ich kümmere mich darum, dass Lindenhain läuft, und heiße Fremde willkommen.",
	"1": "Ich bin der Schmied. Ich schmiede und repariere Waffen und Rüstungen und schmelze altes Eisen ein.",
	"2": "Ich bin Bäuerin. Ich bestelle die Felder und ernte Kürbisse und Korn.",
	"3": "Ich bin Holzfäller. Ich fälle Bäume und liefere Bauholz.",
	"4": "Ich bin die Wache. Ich halte Tag und Nacht Ausschau nach Gefahr.",
	"5": "Arbeit? Ich trinke, ich erzähle und ich höre zu. Im Wirtshaus bin ich unentbehrlich.",
	"6": "Ich bin die Krämerin. Ich verkaufe Brot, Seile, Fackeln und kaufe, was du aus dem Verlies mitbringst.",
	"7": "Meine Arbeit? Ich passe auf die Ziegen auf! Und ich spiele Fangen.",
	"pippi": "Ich hüte mit Pip die Gänse und die Ziegen. Und wir spielen Fangen!",
	"8": "Ich bin Gelehrter. Ich lese, forsche und schreibe auf, was ich über die Gruft herausfinde.",
	"9": "Ich bin Wasserträgerin. Ich hole frisches Wasser vom Brunnen und bringe es ins Dorf.",
	"sweeper": "Ich bin Straßenfeger. Im Herbst kehre ich das Laub von den Wegen, im Winter schiebe ich den Schnee beiseite.",
	"K": "Ich bin der Herold der Krone. Ich rufe auf dem Platz die Neuigkeiten aus.",
	"µ": "Ich bin Raumausstatterin. Ich verkaufe Betten, Truhen, Regale und Kamine für dein Haus.",
	"¢": "Ich bin der Amtmann. Ich trage Land ins Grundbuch ein, damit du bauen kannst.",
	"O": "Ich bin die Priesterin des Tempels. Ich spende den Segen der Götter und heile Verletzte.",
	"G": "Ich leite die Abenteurergilde. Ich vergebe Aufträge an mutige Helden.",
	"M": "Ich bin der Postmeister. Ich bringe Briefe und Pakete zu jedem Haus im Dorf.",
	"Z": "Ich bin der Barbier. Ich schneide und färbe Haare und tätowiere.",
	"Y": "Ich bin der Bankier. Ich verwahre dein Geld sicher in der Bank der Krone.",
	"ü": "Ich bin der Müller. Ich mahle Korn zu Mehl und verkaufe Körner.",
	"ö": "Ich bin der Brauer. Ich braue Bier und zapfe es im Wirtshaus.",
	"S": "Ich bin der Steinmetz. Ich haue Steinblöcke zurecht, die du zum Bauen kaufen kannst.",
	"φ": "Ich bin Bauer im Tal. Ich pflüge, säe und ernte Weizen, Mais und Sonnenblumen, und im Dorf kaufen sie es mir ab.",
	"ψ": "Ich bin Bäuerin im Tal. Ich säe, jäte, hole Wasser und bringe die Ernte ein, und nebenbei koche ich.",
	"χ": "Ich bin Knecht auf dem Hof. Ich schleppe Säcke und Wasser, hacke Holz und flicke, was kaputt ist.",
	"ω": "Meine Arbeit? Ich helfe Mama! Und ich jage die Krähen!",
	"κ": "Ich bin Kletterer. Ich steige die Wand dort hinauf, ruhe oben aus und steige wieder ab. Jeden Tag, bei jedem Wetter.",
	"β": "Ich bin Imker. Ich pflege die Stöcke, sehe nach dem Schwärmen und verkaufe den besten Honig im Tal.",
	"λ": "Ich bin Hirte. Ich hüte die Schafe im Tal und achte darauf, dass keins im Mais landet.",
	"%": "Ich bin Wanderhändler. Ich komme jede dritte Nacht mit seltenen Waren ins Dorf.",
}


## Whether `text` asks about work.
static func asks(text: String) -> bool:
	return HeroChat._has_word(text.to_lower(), WORDS)


## What the villager of this role says about their work, already translated.
static func answer(role: String) -> String:
	if JOBS.has(role):
		return Lang.t(JOBS[role])
	return Lang.t("Ich bin %s.") % Lang.t(Villager.ROLES[role].name)
