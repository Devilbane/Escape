"""Builds the footstep listening page: one card per ground with the steps the game plays now, the six it played
before the Soundza recordings (read from git at the commit given) and every other single step of the library as an
alternative with a "Use" button. Ratings are saved in the browser and can be copied back into the chat.

  python3 make_footstep_preview.py "<audio library folder>" <commit before the Soundza steps> <output.html> [copied picks text]

Give the text copied from an earlier page as the last argument and the steps it lists under RED are left out.
Needs ffmpeg, numpy and git."""
import base64, glob, io, json, os, subprocess, sys, wave
import numpy as np
from make_soundza_steps import GROUNDS, PACK, RATE, read, heel_strikes, step

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
## Ground -> (what the game does with it, library folders its alternatives come from).
CARDS = [
	("grass", "Grass (the village, meadows)", ["grass"]),
	("scree", "Scree (loose stones on the mountain paths)", ["gravel"]),
	("wood", "Wooden floors (houses, bridges, planks)", ["wood"]),
	("paving", "Paving (village squares and cobbled roads)", ["stone"]),
	("path", "Paths (trodden earth roads)", ["dirt"]),
	("soil", "Fields (ploughed soil)", ["mud", "dirt"]),
]
## Recordings that no ground uses yet, to listen to for later.
SPARE = [("leaves", "Dry leaves (not used yet)", ["leaves"]), ("sand", "Sand (not used yet)", ["sand"])]


def wav_uri(y, rate=RATE):
	b = io.BytesIO()
	with wave.open(b, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(rate)
		w.writeframes((np.clip(y, -1, 1) * 32767).astype("<i2").tobytes())
	return "data:audio/wav;base64," + base64.b64encode(b.getvalue()).decode(), round(len(y) / rate, 2)


def game_file(name, rev=None):
	"""The step as the game has it, or as it was at commit `rev`."""
	rel = "assets/sounds/%s.wav" % name
	if rev:
		raw = subprocess.run(["git", "show", "%s:%s" % (rev, rel)], cwd=ROOT, capture_output=True, check=True).stdout
		path = os.path.join("/tmp", "preview_" + name + ".wav")
		open(path, "wb").write(raw)
	else:
		path = os.path.join(ROOT, rel)
	return read(path)


def candidates(folder, folders, used, excluded=()):
	out = []
	for sub in folders:
		for f in sorted(glob.glob(os.path.join(folder, PACK, sub, "*.wav"))):
			x = read(f)
			if len(x) / RATE > 1.2 or not len(x):
				continue
			hits = heel_strikes(x)
			for n in range(len(hits)):
				if "%s/%s#%d" % (sub, os.path.basename(f), n) in excluded:
					continue
				label = os.path.basename(f)[8:-4] + ((" #%d" % (n + 1)) if len(hits) > 1 else "")
				uri, dur = wav_uri(step(x, n, 0.4))
				out.append({"id": "%s/%s#%d" % (sub, os.path.basename(f), n), "label": label, "src": uri, "dur": dur,
							"used": (sub + "/" + os.path.basename(f), n) in used})
	return out


def main(folder, before, out, exclusions=None):
	excluded = set()
	if exclusions:
		# The text copied from the page: the lines under a "RED" heading are left out.
		red = False
		for line in open(exclusions):
			if line.strip().endswith(":") and not line.startswith("-"):
				red = line.startswith("RED")
			elif red and line.startswith("- ") and line.rstrip().endswith(")"):
				excluded.add(line.rstrip()[line.rindex("(") + 1:-1])
	cards = []
	for key, title, subs in CARDS + SPARE:
		spare = (key, title, subs) in SPARE
		used = set(GROUNDS[key][2]) if key in GROUNDS else set()
		now = [] if spare else [dict(zip(("src", "dur"), wav_uri(game_file("step_%s_%d" % (key, k))))) | {"label": "Step %d" % (k + 1)} for k in range(6)]
		old_key = {"paving": "", "path": "dirt", "soil": "dirt"}.get(key, key)
		old = [] if spare else [dict(zip(("src", "dur"), wav_uri(game_file("step_%s%d" % (old_key + "_" if old_key else "", k), before)))) | {"label": "Step %d" % (k + 1)} for k in range(6)]
		cards.append({"key": key, "title": title, "spare": spare, "now": now, "old": old, "alts": candidates(folder, subs, used, excluded)})
	html = TEMPLATE.replace("/*DATA*/", "const DATA=" + json.dumps(cards) + ";")
	open(out, "w").write(html)
	print(out, round(len(html) / 1e6, 1), "MB")


TEMPLATE = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Escape! Footstep Preview</title>
<style>
:root{--bg:#1b1713;--card:#262019;--line:#4a3c2c;--text:#eadfca;--dim:#a99a80;--gold:#d9a441;--btn:#3a2f22;--on:#7a2f23}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:15px/1.45 system-ui,Segoe UI,sans-serif}
header{position:sticky;top:0;z-index:5;background:#120f0c;border-bottom:1px solid var(--line);padding:10px 16px;display:flex;gap:12px;align-items:center;flex-wrap:wrap}
header h1{font-size:18px;margin:0;color:var(--gold)}header .now{flex:1;color:var(--dim);min-width:160px}
main{max-width:1100px;margin:0 auto;padding:8px 16px 60px}h2{color:var(--gold);border-bottom:1px solid var(--line);padding-bottom:6px;margin-top:30px}
h4{margin:10px 0 4px;font-size:12px;color:var(--dim);text-transform:uppercase;letter-spacing:.04em}
p.intro{color:var(--dim)}.row{display:flex;flex-wrap:wrap;gap:6px}.alt{display:flex;gap:2px}
button{font:inherit;font-size:13px;background:var(--btn);color:var(--text);border:1px solid var(--line);border-radius:4px;cursor:pointer;padding:6px 10px}
button:hover{border-color:var(--gold)}button.on{background:var(--on)}button.v{width:210px;text-align:left;display:flex;justify-content:space-between}
button.nf{margin-left:8px}.gone{display:none}.used{border-left:3px solid #4c8a4c}button.v.green{background:#2f5a2f}button.v.yellow{background:#8a6a1c}button.v.red{background:#6e2a22;text-decoration:line-through;opacity:.7}button.v.on{outline:2px solid var(--gold)}.menu{display:none;position:absolute;z-index:20;flex-direction:column;width:226px;background:#120f0c;border:1px solid var(--gold);border-radius:6px;padding:4px;gap:3px}.menu .green{background:#2f5a2f}.menu .yellow{background:#8a6a1c}.menu .red{background:#6e2a22}.d{color:var(--dim);font-size:12px}
.card{background:var(--card);border:1px solid var(--line);border-radius:6px;padding:10px 14px;margin:12px 0}.rate button.sel{background:#8a6a1c;color:#fff}
</style></head><body>
<header><h1>Escape! Footstep Preview</h1><div class="now" id="now">Nothing playing</div>
<label>Volume <input id="vol" type="range" min="0" max="1" step="0.05" value="0.8"></label>
<span id="count" style="color:var(--dim)"></span><button id="all">Play the six in a row</button><button id="hide">Hide red sounds</button><button id="stop">Stop</button><button id="copy">Copy ratings</button></header>
<main><p class="intro">Each ground shows the six steps the game plays now, the six it played before, and every other single step of the library. Click a sound to hear it; <b>right-click</b> it (touch screens: press and hold) to rate it: <b>green</b> = use this, <b>yellow</b> = a considered alternative, <b>red</b> = exclude from future proposals. "Nothing fits" marks every unrated proposal of a ground red. Ratings are saved in this browser; "Copy ratings" gives all three lists to paste into the chat, and the generator leaves the red ones out of the next version of the page.</p><div id="root"></div></main>
<script>
/*DATA*/
const root=document.getElementById('root'),now=document.getElementById('now');
const KEY='escape-step-rates';let rates={};try{rates=JSON.parse(localStorage.getItem(KEY)||'{}')}catch(e){}
const NAMES={green:'Green: use this',yellow:'Yellow: considered alternative',red:'Red: exclude from future proposals'};
const audio=new Audio();audio.volume=.8;let cur=null,queue=[],hideRed=false;
const el=(t,c,x)=>{const e=document.createElement(t);if(c)e.className=c;if(x!==undefined)e.textContent=x;return e};
const save=()=>{try{localStorage.setItem(KEY,JSON.stringify(rates))}catch(e){}};
function stop(){queue=[];audio.pause();if(cur)cur.classList.remove('on');cur=null;now.textContent='Nothing playing'}
function play(b,v,name){if(cur===b){stop();return}audio.pause();if(cur)cur.classList.remove('on');audio.src=v.src;audio.currentTime=0;audio.play().catch(()=>{});cur=b;b.classList.add('on');now.textContent='Playing: '+name}
audio.onended=()=>{if(queue.length){const q=queue.shift();play(q[0],q[1],q[2])}else stop()};
const all=[];
function paint(x){x.b.classList.remove('green','yellow','red');const r=rates[x.id];if(r)x.b.classList.add(r);x.b.parentElement.classList.toggle('gone',hideRed&&r==='red')}
function rate(x,r){if(r)rates[x.id]=r;else delete rates[x.id];save();paint(x);counts()}
function counts(){const n={green:0,yellow:0,red:0};for(const k in rates)n[rates[k]]++;document.getElementById('count').textContent='Green '+n.green+' · Yellow '+n.yellow+' · Red '+n.red}
const menu=el('div','menu');document.body.append(menu);
for(const r of ['green','yellow','red',null]){const m=el('button',r||'clear',r?NAMES[r]:'Clear rating');m.onclick=()=>{rate(menu.x,r);menu.style.display='none'};menu.append(m)}
document.addEventListener('click',()=>menu.style.display='none');document.addEventListener('scroll',()=>menu.style.display='none');
function mk(v,id,name,box){const w=el('span','snd'),b=el('button','v');b.append(el('span',0,v.label),el('span','d',v.dur+' s'));
 const x={id,b,v};b.onclick=()=>{queue=[];play(b,v,name+' '+v.label)};
 b.oncontextmenu=e=>{e.preventDefault();menu.x=x;menu.style.display='flex';menu.style.left=Math.min(e.pageX,innerWidth-230)+'px';menu.style.top=e.pageY+'px'};
 let t;b.ontouchstart=e=>{t=setTimeout(()=>{const q=e.touches[0];menu.x=x;menu.style.display='flex';menu.style.left=Math.min(q.pageX,innerWidth-230)+'px';menu.style.top=q.pageY+'px'},600)};b.ontouchend=b.ontouchmove=()=>clearTimeout(t);
 w.append(b);box.append(w);all.push(x);paint(x);return b}
for(const c of DATA){
 root.append(el('h2',0,c.title));const card=el('div','card');c.items=[];
 for(const [h,list,tag] of [['In game now',c.now,'now'],['Before (the older steps)',c.old,'old']]){if(!list.length)continue;card.append(el('h4',0,h));const r=el('div','row');
  list.forEach((v,i)=>{const b=mk(v,tag+':'+c.key+':'+i,c.key,r);if(tag==='now')c.items.push([b,v])});card.append(r)}
 const hd=el('h4',0,'Other steps in the library (right-click a sound to rate it)');const nf=el('button','nf','Nothing fits');nf.title='Mark every unrated proposal for this ground red';hd.append(nf);card.append(hd);
 const r=el('div','row');for(const a of c.alts){const b=mk(a,a.id,c.key,r);if(a.used)b.classList.add('used')}
 nf.onclick=()=>{for(const a of c.alts)if(!rates[a.id])rates[a.id]='red';save();all.forEach(paint);counts()};
 card.append(r);root.append(card);c.firstRow=card}
document.getElementById('stop').onclick=stop;
document.getElementById('vol').oninput=e=>audio.volume=+e.target.value;
document.getElementById('hide').onclick=e=>{hideRed=!hideRed;e.target.textContent=hideRed?'Show red sounds':'Hide red sounds';all.forEach(paint)};
document.getElementById('all').onclick=()=>{const c=DATA.find(d=>d.items.length&&d.firstRow.getBoundingClientRect().bottom>0)||DATA[0];if(!c.items.length)return;stop();queue=c.items.slice(1).map(([b,v])=>[b,v,c.key+' '+v.label]);const f=c.items[0];play(f[0],f[1],c.key+' '+f[1].label)};
function report(){let t='Escape! footstep ratings\n';const L=[['green','GREEN (use these)'],['yellow','YELLOW (considered alternatives)'],['red','RED (exclude from future proposals)']];
 for(const c of DATA){const ids=[...c.alts.map(a=>[a.id,a.label]),...c.now.map((v,i)=>['now:'+c.key+':'+i,'in game: '+v.label]),...c.old.map((v,i)=>['old:'+c.key+':'+i,'before: '+v.label])];
  let s='';for(const [r,h] of L){const m=ids.filter(([i])=>rates[i]===r);if(m.length)s+=h+':\n'+m.map(([i,l])=>'- '+l+'  ('+i+')').join('\n')+'\n'}
  if(s)t+='\n== '+c.title+'\n'+s}return t}
document.getElementById('copy').onclick=async e=>{const t=report();try{await navigator.clipboard.writeText(t)}catch(x){const a=document.createElement('textarea');a.value=t;document.body.append(a);a.select();document.execCommand('copy');a.remove()}e.target.textContent='Copied!';setTimeout(()=>e.target.textContent='Copy ratings',1500)};
counts();
</script></body></html>"""

if __name__ == "__main__":
	main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
