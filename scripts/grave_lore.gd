class_name GraveLore
extends RefCounted
## The names and inscriptions of the graveyard's gravestones (the tiles "g" of the outdoor map). Run into
## a gravestone to read it: its name and a line cut into the stone, funny, fancy or macabre. Every stone
## keeps its text for good (it follows from the stone's place among the graves, not from chance).
##
## One of the stones, Owlav Hearing's, hints at the owl clock (see OwlClock): the line says whom to listen
## to and when, and nothing more. All the texts are our own.
## The texts are German, with English entries in scripts/lang/grave_lore.gd.

const KIND := "grabstein"
## The stone of the one who listened to the night (see OwlClock).
const OWLAV := {"name": "Owlav Hearing",
	"text": "Er hörte, was die Nacht verschwieg. Wenn der Mond sich rundet, lausche den Eulen und läute es ihm zurück."}
## How it reads in the compendium.
const OWLAV_LORE := "Owlav Hearings Grabstein: „Er hörte, was die Nacht verschwieg. Wenn der Mond sich rundet, lausche den Eulen und läute es ihm zurück.“"
## Everybody else, funny, fancy and macabre, in no particular order.
const OTHERS := [
	{"name": "Brannwin Quast", "text": "Er sagte, die Suppe sei nicht vergiftet. Er hatte recht: Es war der Pilz."},
	{"name": "Edda Fenmoor", "text": "Sie liebte ihren Garten so sehr, dass sie jetzt darin bleibt."},
	{"name": "Hartmut Sprenger", "text": "Er wollte nur kurz nachsehen, ob die Falle noch scharf ist."},
	{"name": "Lisbeth von Aschenhain", "text": "Edel im Leben, edel im Tod. Nur die Mäuse sind nicht beeindruckt."},
	{"name": "Gundel Knorr", "text": "Sie kam ihr Leben lang zu spät. Hier ist sie endlich früh dran."},
	{"name": "Tilo Ungeduld", "text": "Er konnte nicht warten. Jetzt wartet er."},
	{"name": "Wolfram Dachs", "text": "Gefallen im Kampf gegen eine Leiter."},
	{"name": "Mathilde Ruß", "text": "Ihr Brot war ein Verbrechen. Möge die Erde gnädiger mit ihr sein als ihre Gäste."},
	{"name": "Jorik Zwirn", "text": "Er flickte die ganze Welt, nur seine eigene Hose nicht."},
	{"name": "Alrun Weidenbach", "text": "Ein Licht erlosch. Die Sterne aber wissen, wie hell es brannte."},
	{"name": "Brosius Bein", "text": "Er hielt nie viel von sich. Jetzt hält er nur noch von selbst zusammen."},
	{"name": "Frieda Nachtigall", "text": "Sie sang bis zuletzt. Die Raben singen noch heute mit."},
	{"name": "Ottmar Faulbaum", "text": "Er wusste, wo der Schatz liegt. Jetzt liegt er selbst darauf."},
	{"name": "Sibylle Grau", "text": "Wer dies liest, steht auf mir. Ich bitte um etwas mehr Respekt, wenigstens am Kopfende."},
	{"name": "Kunibert Pfeil", "text": "Er behauptete bis zuletzt, er sei nur müde."},
	{"name": "Rosamunde Eisenkopf", "text": "Dickschädel bis zum Schluss. Der Stein hat nachgegeben, sie nicht."},
	{"name": "Meister Lamprecht", "text": "Die Zeit heilt alle Wunden. Bei ihm hat sie sich besonders viel Zeit gelassen."},
	{"name": "Gerlind Moos", "text": "Der Mond war ihr Freund, der Nebel ihr Gewand."},
	{"name": "Balduin Kerzenschein", "text": "Er fürchtete die Dunkelheit. Man hat ihm eine Laterne dagelassen."},
	{"name": "Hedwig Tannenzapf", "text": "Sie verlor ihren Schlüssel. Er liegt jetzt bei ihr, und niemand schließt mehr auf."},
	{"name": "Egbert der Schweigsame", "text": "Egbert sagte nie viel. Hier sagt er nichts mehr, aber ausführlich."},
	{"name": "Agnes Rabenfeld", "text": "Sie war nie allein. Die Raben und die Würmer leisten ihr Gesellschaft."},
]


## The name and the inscription of the stone with the number `index` among the others (the graves in
## reading order, Owlav's left out). More graves than texts start over.
static func other(index: int) -> Dictionary:
	return OTHERS[posmod(index, OTHERS.size())]


## What a stone says, as the message shows it.
static func card(entry: Dictionary) -> String:
	return Lang.t(entry.name) + "\n„" + Lang.t(entry.text) + "“"
