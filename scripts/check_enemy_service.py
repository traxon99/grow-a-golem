#!/usr/bin/env python3
"""Exercise real enemy death/reward dispatch without a Roblox physics engine."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/server/Services/EnemyService.luau").read_text()
source = re.sub(r"local (\w+) = require\([^\n]+\)", r"local \1 = dependencies.\1", source)
config = (ROOT / "src/shared/Config.luau").read_text()
settings = config[config.index("Config.Golem = {"):config.index("-- Total XP")]
stagger = config[config.index("Config.BossStagger = {"):config.index("Config.Nodes = {")]
bundle = (
    "local Config = {}\n" + settings + "\n" + stagger
    + "\nlocal MarbleBag = (function()\n" + (ROOT / "src/shared/MarbleBag.luau").read_text() + "\nend)()\n"
    + "\nlocal function loadEnemyService(dependencies, game, Instance, Vector3, CFrame, Enum, clock)\n"
    + "local os = { clock = clock }\n" + source + "\nend\n"
    + (ROOT / "tests/enemy-service.luau").read_text()
)
with tempfile.TemporaryDirectory(prefix="golem-enemy-service-") as directory:
    test = Path(directory) / "enemy-service.luau"
    test.write_text(bundle)
    subprocess.run([os.environ.get("LUAU", "luau"), str(test)], check=True, cwd=ROOT)
