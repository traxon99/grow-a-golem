#!/usr/bin/env python3
"""Compile every Luau file and run pure logic tests with small Roblox value shims.

Requires luau and luau-compile on PATH, or LUAU / LUAU_COMPILE overrides.
This does not emulate Studio physics, DataStores, UI, or platform purchases.
"""
import os
import re
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
compiler = os.environ.get("LUAU_COMPILE", "luau-compile")
runner = os.environ.get("LUAU", "luau")
files = sorted(ROOT.glob("src/**/*.luau")) + sorted(ROOT.glob("tests/*.luau"))
subprocess.run([compiler, "--null", *map(str, files)], check=True)
prelude = '''local Color3 = { fromRGB = function(r, g, b) return { R = r/255, G = g/255, B = b/255 } end }
local Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
local Enum = setmetatable({}, { __index = function(_, kind)
 return setmetatable({}, { __index = function(_, name) return kind .. "." .. name end })
end })
'''
config = (ROOT / "src/shared/Config.luau").read_text()
stats = (ROOT / "src/shared/Stats.luau").read_text().replace(
    'local Config = require(script.Parent:WaitForChild("Config"))', '')
lease = (ROOT / "src/shared/SessionLease.luau").read_text()
bundle = prelude + '\nlocal Config = (function()\n' + config + '\nend)()\n'
bundle += 'local Stats = (function()\n' + stats + '\nend)()\n'
bundle += 'local SessionLease = (function()\n' + lease + '\nend)()\n'
journal = (ROOT / "src/shared/TradeJournal.luau").read_text()
bundle += 'local TradeJournal = (function()\n' + journal + '\nend)()\n'
bundle += (ROOT / "tests/regression.luau").read_text()
# Exercise the actual server handlers with mocked services, including repeated
# requests. This avoids a test that merely repeats the Ascension implementation.
progression = (ROOT / "src/server/Services/ProgressionService.luau").read_text()
progression = re.sub(r'local (\w+) = require\([^\n]+\)', r'local \1 = dependencies.\1', progression)
bundle += "\nlocal task = { spawn = function() end }\nlocal function loadProgression(dependencies)\n"
bundle += 'local game = { GetService = function() return { WaitForChild = function() return {} end } end }\n'
bundle += 'local script = { Parent = {} }\n'
bundle += progression + "\nend\n"
bundle += (ROOT / "tests/progression.luau").read_text()
data_service = (ROOT / "src/server/Services/DataService.luau").read_text()
data_service = re.sub(r'local (\w+) = require\([^\n]+\)', r'local \1 = dependencies.\1', data_service)
bundle += "\nlocal function loadDataService(dependencies, game, Instance)\n"
bundle += 'local task = { spawn = function() end, wait = function() end }\nlocal warn = function() end\n'
bundle += 'local script = { Parent = {} }\n' + data_service + "\nend\n"
bundle += (ROOT / "tests/data-service.luau").read_text()
# The real TradeService, with its requires swapped for mocks; the test drives
# its action handlers and simulates crashes by reloading from written saves.
trade_service = (ROOT / "src/server/Services/TradeService.luau").read_text()
trade_service = re.sub(r'local (\w+) = require\([^\n]+\)', r'local \1 = dependencies.\1', trade_service)
bundle += "\nlocal function loadTradeService(dependencies, game, task)\n"
bundle += 'local warn = function() end\nlocal script = { Parent = {} }\n' + trade_service + "\nend\n"
bundle += (ROOT / "tests/trade-service.luau").read_text()
with tempfile.TemporaryDirectory(prefix="golem-check-") as folder:
    path = Path(folder) / "regression.luau"
    path.write_text(bundle)
    subprocess.run([runner, str(path)], check=True, cwd=ROOT)
print(f"Checked {len(files)} Luau files; Studio playtests are still required.")
