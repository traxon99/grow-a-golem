#!/usr/bin/env python3
"""Run GolemService recovery rules with lightweight engine dependencies."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/server/Services/GolemService.luau").read_text()
source = re.sub(r"local (\w+) = require\([^\n]+\)", r"local \1 = dependencies.\1", source)
config = (ROOT / "src/shared/Config.luau").read_text()
settings = config[config.index("Config.Golem = {"):config.index("-- Total XP")]
bundle = (
    "local Config = {}\n" + settings
    + "\nlocal function loadGolemService(dependencies, game, Vector3, CFrame, clock)\n"
    + "local os = { clock = clock }\n" + source + "\nend\n"
    + (ROOT / "tests/golem-service.luau").read_text()
)
with tempfile.TemporaryDirectory(prefix="golem-service-") as directory:
    test = Path(directory) / "golem-service.luau"
    test.write_text(bundle)
    subprocess.run([os.environ.get("LUAU", "luau"), str(test)], check=True, cwd=ROOT)
