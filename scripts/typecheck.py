#!/usr/bin/env python3
"""Type-check src/ with luau-lsp and the Roblox definitions, against a baseline.

The code was written before CI had a type checker, so strict mode reports
existing problems in many files. scripts/type-baseline.json records how many
each file has today. This fails if any file gets more than its baseline (or a
new file has any), so new code can't add type errors. When you fix some, run
with --update to lower the baseline in the same PR.

Requires luau-lsp on PATH (or LUAU_LSP), a sourcemap.json from
`rojo sourcemap default.project.json -o sourcemap.json`, and the definitions
file passed with --definitions.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "scripts/type-baseline.json"
# A diagnostic starts with: <path> [<instance path>](line,col): Kind: message
HEADER = re.compile(r"^(?P<path>\S+\.luau)(?: \[[^\]]*\])?\((?P<line>\d+),(?P<col>\d+)\): (?P<kind>\w+): ")

parser = argparse.ArgumentParser()
parser.add_argument("--definitions", required=True)
parser.add_argument("--update", action="store_true", help="rewrite the baseline from this run")
args = parser.parse_args()

result = subprocess.run(
    [
        os.environ.get("LUAU_LSP", "luau-lsp"),
        "analyze",
        "--platform=roblox",
        "--sourcemap=sourcemap.json",
        f"--definitions={args.definitions}",
        "src",
    ],
    cwd=ROOT,
    capture_output=True,
    text=True,
)
output = result.stdout + result.stderr
if "Failed to load definitions" in output:
    sys.exit(output + "\nluau-lsp could not load the Roblox definitions; check the pinned versions match.")

counts: dict[str, int] = {}
lines: dict[str, list[str]] = {}
seen: set[str] = set()
for raw in output.splitlines():
    match = HEADER.match(raw)
    # luau-lsp repeats a module's diagnostics for each module that requires it.
    if not match or raw in seen:
        continue
    seen.add(raw)
    path = Path(match["path"])
    rel = (path if path.is_absolute() else ROOT / path).resolve().relative_to(ROOT).as_posix()
    counts[rel] = counts.get(rel, 0) + 1
    lines.setdefault(rel, []).append(raw)

if args.update:
    BASELINE.write_text(json.dumps(dict(sorted(counts.items())), indent=2) + "\n")
    print(f"Wrote {BASELINE.relative_to(ROOT)}: {sum(counts.values())} diagnostics in {len(counts)} files.")
    sys.exit(0)

baseline: dict[str, int] = json.loads(BASELINE.read_text())
worse = sorted(f for f in counts if counts[f] > baseline.get(f, 0))
better = sorted(f for f in baseline if counts.get(f, 0) < baseline[f])

for f in worse:
    print(f"::error file={f}::{f} has {counts[f]} type diagnostics, baseline is {baseline.get(f, 0)}")
    for raw in lines[f]:
        print("  " + raw.replace(str(ROOT) + "/", ""))
        # One annotation per diagnostic, so the PR shows each line and message.
        match = HEADER.match(raw)
        if match:
            message = raw[match.end() :].strip()
            print(f"::warning file={f},line={match['line']},col={match['col']}::{match['kind']}: {message}")
for f in better:
    print(f"{f}: {counts.get(f, 0)} type diagnostics, down from {baseline[f]}. Run scripts/typecheck.py --update to lock it in.")

if worse:
    sys.exit(f"{len(worse)} file(s) gained type diagnostics. Fix them, or explain in the PR why the baseline must rise.")
print(f"Type check: {sum(counts.values())} known diagnostics, none new.")
