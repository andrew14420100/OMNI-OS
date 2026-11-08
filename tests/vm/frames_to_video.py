#!/usr/bin/env python3
"""Converte i fotogrammi PPM di qmp_record.py in un video MP4 a tempo reale.
Uso: frames_to_video.py <dir-fotogrammi> <uscita.mp4>"""
import subprocess
import sys
from pathlib import Path

d, out = Path(sys.argv[1]), sys.argv[2]
times = [float(x) for x in (d / "tempi.txt").read_text().split()]
frames = sorted(d.glob("f*.ppm"))
n = min(len(times), len(frames))
lst = d / "concat.txt"
with lst.open("w") as fh:
    for i in range(n):
        dur = (times[i + 1] - times[i]) if i + 1 < n else 0.2
        fh.write(f"file '{frames[i].resolve()}'\nduration {max(dur, 0.01):.3f}\n")
    fh.write(f"file '{frames[n - 1].resolve()}'\n")
subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(lst),
                "-vf", "fps=15,format=yuv420p", "-c:v", "libx264", "-crf", "22", "-movflags", "+faststart", out], check=True)
print(f"video: {out} ({n} fotogrammi, {times[n - 1]:.1f} s)")
