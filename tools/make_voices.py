"""Builds the hero's cries for the comic words ("AUA!", "UFF!", "AUTSCH!")
with the Piper speech synthesizer and the CC0 Thorsten voice (angry tone).
Run: pip install piper-tts, then python3 tools/make_voices.py
The voice model is downloaded once into tools/.voices (not committed)."""
import os, subprocess, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "sounds")
CACHE = os.path.join(HERE, ".voices")
MODEL = "de_DE-thorsten_emotional-medium"
URL = "https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/thorsten_emotional/medium/"
ANGRY = "1"

# Sound name -> what the voice says. The English words are close enough:
# "Autsch" sounds like "Ouch", "Uff" like "Oof" and "Au" like "Ow".
CRIES = {
    "voice_aua": "Aua!",
    "voice_uff": "Uff!",
    "voice_autsch": "Autsch!",
    "voice_au": "Au!",
}


def fetch():
    os.makedirs(CACHE, exist_ok=True)
    for ext in [".onnx", ".onnx.json"]:
        path = os.path.join(CACHE, MODEL + ext)
        if not os.path.exists(path):
            urllib.request.urlretrieve(URL + MODEL + ext, path)
    return os.path.join(CACHE, MODEL + ".onnx")


def say(model, text, name):
    raw = os.path.join(CACHE, name + "_raw.wav")
    subprocess.run(["python3", "-m", "piper", "-m", model, "-s", ANGRY, "--length-scale", "0.85",
                    "-f", raw], input=text.encode(), check=True, capture_output=True)
    # Cut the silence, raise the voice a little (younger, more strained),
    # give it a short dungeon echo and keep it short and loud.
    filters = ",".join([
        "silenceremove=start_periods=1:start_threshold=-45dB",
        "areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse",
        "asetrate=22050*1.07,aresample=22050",
        "highpass=f=120",
        "aecho=0.8:0.5:60|110:0.25|0.12",
        "apad=pad_dur=0.08",
        "loudnorm=I=-14:TP=-1.5",
        "aresample=22050",
    ])
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af", filters, "-ac", "1",
                    "-c:a", "pcm_s16le", os.path.join(OUT, name + ".wav")], check=True)
    os.remove(raw)


if __name__ == "__main__":
    model = fetch()
    for name, text in CRIES.items():
        say(model, text, name)
