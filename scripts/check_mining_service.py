#!/usr/bin/env python3
"""Exercise real MiningService damage attribution with lightweight Roblox shims."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/server/Services/MiningService.luau").read_text()
source = re.sub(r"local (\w+) = require\([^\n]+\)", r"local \1 = dependencies.\1", source)
bundle = (
    "local function loadMiningService(dependencies, game, Instance, Vector3, CFrame, Enum, Color3, task)\n"
    + "local script = { Parent = {} }\n"
    + source
    + "\nend\n"
    + (ROOT / "tests/mining-service.luau").read_text()
)
with tempfile.TemporaryDirectory(prefix="golem-mining-service-") as directory:
    test = Path(directory) / "mining-service.luau"
    test.write_text(bundle)
    subprocess.run([os.environ.get("LUAU", "luau"), str(test)], check=True, cwd=ROOT)
