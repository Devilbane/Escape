"""Seals a riddle's answer for scripts/riddle_seal.gd (RiddleSeal.open).
Usage: python3 tools/riddle_seal.py "text"   (prints the sealed text; do not paste the answer anywhere else)"""
import base64
import sys

KEY = b"Apfeltal-Nacht"

if __name__ == "__main__":
    data = sys.argv[1].encode()
    print(base64.b64encode(bytes(c ^ KEY[i % len(KEY)] for i, c in enumerate(data))).decode())
