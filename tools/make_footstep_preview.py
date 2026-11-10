"""Builds the footstep listening page: one card per ground with the steps the game plays now, the six it played
before the Soundza recordings (read from git at the commit given) and every other single step of the library as an
alternative with a "Use" button. Picks are saved in the browser and can be copied back into the chat.

  python3 make_footstep_preview.py "<audio library folder>" <commit before the Soundza steps> <output.html> [copied picks text]

Give the text copied from an earlier page as the last argument and the steps it lists under "Nothing fits" are left out.
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
		# The "Copy picks" text: every line ending in "(<id>)" under a "Nothing fits" heading is left out.
		for line in open(exclusions):
			if line.startswith("- ") and line.rstrip().endswith(")") and "#" in line:
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


TEMPLATE = """<!doctype html>
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
button.nf{margin-left:8px}button.nf.sel{background:#8a2f23;color:#fff}.gone{display:none}button.use{width:64px;color:var(--dim)}button.use.sel{background:#2f5a2f;color:#fff}.used{border-color:#4c8a4c}.d{color:var(--dim);font-size:12px}
.card{background:var(--card);border:1px solid var(--line);border-radius:6px;padding:10px 14px;margin:12px 0}.rate button.sel{background:#8a6a1c;color:#fff}
</style></head><body>
<header><h1>Escape! Footstep Preview</h1><div class="now" id="now">Nothing playing</div>
<label>Volume <input id="vol" type="range" min="0" max="1" step="0.05" value="0.8"></label>
<button id="all">Play the six in a row</button><button id="stop">Stop</button><button id="copy">Copy picks</button></header>
<main><p class="intro">Each ground shows the six steps the game plays now, the six it played before, and every other single step of the library.
Alternatives with a green outline are already in the game. "Nothing fits" removes every proposal of a ground and keeps them out of future versions of this page (the copied text lists them). Press "Use" next to the ones you want instead (press again to undo), mark a ground
"Needs another" if it still sounds wrong, then "Copy picks" and paste the text back into the chat.</p><div id="root"></div></main>
<script>
/*DATA*/
const root=document.getElementById('root'),now=document.getElementById('now');
let excl={};try{excl=JSON.parse(localStorage.getItem('escape-step-excluded')||'{}')}catch(e){}
let picks={};try{picks=JSON.parse(localStorage.getItem('escape-step-picks')||'{}')}catch(e){}
const audio=new Audio();audio.volume=.8;let cur=null,queue=[];
const el=(t,c,x)=>{const e=document.createElement(t);if(c)e.className=c;if(x!==undefined)e.textContent=x;return e};
function save(){try{localStorage.setItem('escape-step-excluded',JSON.stringify(excl))}catch(e){}try{localStorage.setItem('escape-step-picks',JSON.stringify(picks))}catch(e){}}
function stop(){queue=[];audio.pause();if(cur)cur.classList.remove('on');cur=null;now.textContent='Nothing playing'}
function play(b,v,name){if(cur===b){stop();return}audio.pause();if(cur)cur.classList.remove('on');audio.src=v.src;audio.currentTime=0;audio.play().catch(()=>{});cur=b;b.classList.add('on');now.textContent='Playing: '+name}
audio.onended=()=>{if(queue.length){const q=queue.shift();play(q[0],q[1],q[2])}else stop()};
function mk(v,name){const b=el('button','v');b.append(el('span',0,v.label),el('span','d',v.dur+' s'));b.onclick=()=>{queue=[];play(b,v,name+' '+v.label)};return b}
for(const c of DATA){
 root.append(el('h2',0,c.title));const card=el('div','card');
 if(c.now.length){for(const [h,list] of [['In game now',c.now],['Before (the older steps)',c.old]]){card.append(el('h4',0,h));const r=el('div','row');const bs=list.map(v=>mk(v,c.key));bs.forEach(b=>r.append(b));card.append(r);
  if(h==='In game now')c.btns=bs.map((b,i)=>[b,list[i]])}}
 const hd=el('h4',0,'Other steps in the library (press Use to choose)');const nf=el('button','nf','Nothing fits');nf.title='Remove all these proposals for this ground and never propose them again';
 const rr=el('button','nf','Restore proposals');rr.style.display='none';hd.append(nf,rr);card.append(hd);const r=el('div','row');
 for(const a of c.alts){const w=el('div','alt'),b=mk(a,c.key);if(a.used)b.classList.add('used');const u=el('button','use','Use');
  u.onclick=()=>{const k=c.key;picks[k]=picks[k]||{};if(picks[k][a.id])delete picks[k][a.id];else picks[k][a.id]=a.label;save();u.classList.toggle('sel',!!picks[k][a.id])};
  if(picks[c.key]&&picks[c.key][a.id])u.classList.add('sel');w.append(b,u);r.append(w);a.w=w;if(excl[c.key]&&excl[c.key][a.id])w.classList.add('gone')}
 const refresh=()=>{const on=!!(excl[c.key]&&Object.keys(excl[c.key]).length);nf.style.display=on?'none':'';rr.style.display=on?'':'none'};
 nf.onclick=()=>{excl[c.key]={};for(const a of c.alts){excl[c.key][a.id]=a.label;a.w.classList.add('gone')}delete picks[c.key];r.querySelectorAll('button.use').forEach(u=>u.classList.remove('sel'));save();refresh()};
 rr.onclick=()=>{delete excl[c.key];c.alts.forEach(a=>a.w.classList.remove('gone'));save();refresh()};refresh();
 card.append(r);root.append(card)}
document.getElementById('stop').onclick=stop;
document.getElementById('vol').oninput=e=>audio.volume=+e.target.value;
document.getElementById('all').onclick=()=>{const c=DATA.find(d=>d.btns&&d.btns.some(([b])=>b.getBoundingClientRect().top>=0))||DATA[0];if(!c.btns)return;stop();queue=c.btns.slice(1).map(([b,v])=>[b,v,c.key+' '+v.label]);const f=c.btns[0];play(f[0],f[1],c.key+' '+f[1].label)};
document.getElementById('copy').onclick=async e=>{let t='Escape! footstep picks\\n';for(const c of DATA){const p=picks[c.key]||{};const ids=Object.keys(p);const x=excl[c.key]?Object.keys(excl[c.key]):[];if(x.length)t+='\\n'+c.title+' - NOTHING FITS (these are never proposed again):\\n'+x.map(i=>'- '+excl[c.key][i]+'  ('+i+')').join('\\n')+'\\n';if(ids.length)t+='\\n'+c.title+':\\n'+ids.map(i=>'- '+p[i]+'  ('+i+')').join('\\n')+'\\n'}try{await navigator.clipboard.writeText(t)}catch(x){const a=document.createElement('textarea');a.value=t;document.body.append(a);a.select();document.execCommand('copy');a.remove()}e.target.textContent='Copied!';setTimeout(()=>e.target.textContent='Copy picks',1500)};
</script></body></html>"""

if __name__ == "__main__":
	main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
