#!/usr/bin/env python3
"""Draws the README star history chart. Usage: star-chart.py OWNER/REPO OUTDIR"""
import datetime as dt
import json
import os
import sys
import urllib.request

repo, outdir = sys.argv[1], sys.argv[2]
token = os.environ.get("GITHUB_TOKEN", "")


def page(n):
    req = urllib.request.Request(
        f"https://api.github.com/repos/{repo}/stargazers?per_page=100&page={n}",
        headers={"Accept": "application/vnd.github.star+json", "User-Agent": "star-chart"}
        | ({"Authorization": f"Bearer {token}"} if token else {}),
    )
    with urllib.request.urlopen(req) as r:
        return json.load(r)


times, n = [], 1
while batch := page(n):
    times += [dt.datetime.fromisoformat(s["starred_at"].replace("Z", "+00:00")) for s in batch]
    n += 1
times.sort()
now = dt.datetime.now(dt.timezone.utc)
points = [(t, i + 1) for i, t in enumerate(times)] + [(now, len(times))]

W, H, L, R, T, B = 800, 400, 64, 24, 48, 48
t0, t1 = times[0], now
top = max(1000, -(-len(times) // 1000) * 1000)
x = lambda t: L + (t - t0) / (t1 - t0) * (W - L - R)
y = lambda v: H - B - v / top * (H - T - B)

line = " ".join(f"{x(t):.1f},{y(v):.1f}" for t, v in points)
area = f"{L},{H - B} {line} {x(now):.1f},{H - B}"
step = top // 4 if top <= 8000 else top // 5
days = (t1 - t0).days or 1
ticks = [t0 + dt.timedelta(days=d) for d in range(0, days + 1, max(1, days // 5))]

for name, fg, muted, grid, accent in [
    ("light", "#1f2328", "#59636e", "#d1d9e0", "#0969da"),
    ("dark", "#f0f6fc", "#9198a1", "#3d444d", "#4493f8"),
]:
    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
        'font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif">',
        f'<text x="{L}" y="28" font-size="16" font-weight="600" fill="{fg}">Stars over time</text>',
        f'<text x="{W - R}" y="28" font-size="14" text-anchor="end" fill="{muted}">{len(times):,} stars</text>',
    ]
    for v in range(0, top + 1, step):
        svg.append(f'<line x1="{L}" x2="{W - R}" y1="{y(v):.1f}" y2="{y(v):.1f}" stroke="{grid}"/>')
        svg.append(f'<text x="{L - 10}" y="{y(v) + 4:.1f}" font-size="12" text-anchor="end" fill="{muted}">{v:,}</text>')
    for t in ticks:
        svg.append(f'<text x="{x(t):.1f}" y="{H - B + 22}" font-size="12" text-anchor="middle" fill="{muted}">{t:%b} {t.day}</text>')
    svg += [
        f'<polygon points="{area}" fill="{accent}" fill-opacity="0.12"/>',
        f'<polyline points="{line}" fill="none" stroke="{accent}" stroke-width="2.5" stroke-linejoin="round"/>',
        "</svg>",
    ]
    with open(os.path.join(outdir, f"stars-{name}.svg"), "w") as f:
        f.write("\n".join(svg) + "\n")
print(len(times))
