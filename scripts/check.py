#!/usr/bin/env python3
"""Compile every Luau file and run pure logic tests with small Roblox value shims.

Requires luau and luau-compile on PATH, or LUAU / LUAU_COMPILE overrides.
This does not emulate Studio physics, DataStores, UI, or platform purchases.
"""
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
compiler = os.environ.get("LUAU_COMPILE", "luau-compile")
runner = os.environ.get("LUAU", "luau")
files = sorted(ROOT.glob("src/**/*.luau")) + sorted(ROOT.glob("tests/*.luau"))
compiled = subprocess.run([compiler, "--null", *map(str, files)], capture_output=True, text=True)
if compiled.returncode != 0:
    sys.stderr.write(compiled.stdout + compiled.stderr)
    if os.environ.get("GITHUB_ACTIONS"):
        for line in (compiled.stdout + compiled.stderr).strip().splitlines()[:8]:
            print(f"::error title=Luau compile::{line}")
    sys.exit(compiled.returncode)
prelude = '''local Color3 = { fromRGB = function(r, g, b) return { R = r/255, G = g/255, B = b/255 } end }
local Vector3 = {}
do
 local mt = {}
 mt.__index = function(v, key) if key == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end return nil end
 mt.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
 mt.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
 mt.__mul = function(a, b)
  if type(a) == "number" then return Vector3.new(a * b.X, a * b.Y, a * b.Z) end
  if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
  return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
 end
 Vector3.new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, mt) end
 Vector3.zero = Vector3.new(0, 0, 0)
end
local Enum = setmetatable({}, { __index = function(_, kind)
 return setmetatable({}, { __index = function(_, name) return kind .. "." .. name end })
end })
-- A seeded LCG, not Roblox's real Random: deterministic and good enough for
-- tests that read back whatever it picked rather than predicting exact values.
local Random = {}
do
 local methods = {}
 methods.NextInteger = function(self, a, b)
  self.seed = (self.seed * 1103515245 + 12345) % 2147483648
  return a + (self.seed % (b - a + 1))
 end
 methods.NextNumber = function(self, a, b)
  a = a or 0
  b = b or 1
  self.seed = (self.seed * 1103515245 + 12345) % 2147483648
  return a + (self.seed / 2147483648) * (b - a)
 end
 Random.new = function(seed)
  return setmetatable({ seed = (seed or 0) % 2147483648 }, { __index = methods })
 end
end
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
# The real TowerService with mocked services and a test-controlled clock.
tower_service = (ROOT / "src/server/Services/TowerService.luau").read_text()
tower_service = re.sub(r'local (\w+) = require\([^\n]+\)', r'local \1 = dependencies.\1', tower_service)
bundle += "\nlocal function loadTowerService(dependencies, game, task, clock)\n"
bundle += 'local os = { clock = clock, time = os.time }\nlocal warn = function() end\nlocal script = { Parent = {} }\n'
bundle += tower_service + "\nend\n"
bundle += (ROOT / "tests/tower-service.luau").read_text()
# The real CodeService with mocked services and test-controlled os.clock/os.time.
code_service = (ROOT / "src/server/Services/CodeService.luau").read_text()
code_service = re.sub(r'local (\w+) = require\([^\n]+\)', r'local \1 = dependencies.\1', code_service)
bundle += "\nlocal function loadCodeService(dependencies, game, clock, time)\n"
bundle += 'local os = { clock = clock, time = time }\nlocal task = { spawn = function() end }\n'
bundle += 'local script = { Parent = {} }\n'
bundle += code_service + "\nend\n"
bundle += (ROOT / "tests/code-service.luau").read_text()
# The real LiveEventService with mocked services and a test-controlled os.time.
# task.spawn only queues (never runs) so the service's own background loop,
# started by .start(), never actually executes inside the test.
live_event_service = (ROOT / "src/server/Services/LiveEventService.luau").read_text()
live_event_service = re.sub(r'local (\w+) = require\([^\n]+\)', r'local \1 = dependencies.\1', live_event_service)
bundle += "\nlocal function loadLiveEventService(dependencies, game, task, time)\n"
bundle += 'local os = { time = time }\nlocal script = { Parent = {} }\n'
bundle += live_event_service + "\nend\n"
bundle += (ROOT / "tests/live-event-service.luau").read_text()
# The real RewardService with mocked services and a test-controlled os.time.
# task.spawn/task.wait are no-ops so .start()'s ProfileLoaded hook (offline
# mining, the group-join check) never actually runs inside the test.
reward_service = (ROOT / "src/server/Services/RewardService.luau").read_text()
reward_service = re.sub(r'local (\w+) = require\([^\n]+\)', r'local \1 = dependencies.\1', reward_service)
bundle += "\nlocal function loadRewardService(dependencies, game, task, time)\n"
bundle += 'local os = { time = time }\nlocal script = { Parent = {} }\n'
bundle += reward_service + "\nend\n"
bundle += (ROOT / "tests/reward-service.luau").read_text()
# The real PolicyService with mocked services. check() is only reachable
# through the ProfileLoaded callback .start() registers, so task.spawn here
# actually runs its callback (unlike every other wrapper's no-op) while
# task.wait stays a no-op so the retry loop's real-second delays don't happen.
policy_service = (ROOT / "src/server/Services/PolicyService.luau").read_text()
policy_service = re.sub(r'local (\w+) = require\([^\n]+\)', r'local \1 = dependencies.\1', policy_service)
bundle += "\nlocal function loadPolicyService(dependencies, game, task)\n"
bundle += 'local warn = function() end\nlocal script = { Parent = {} }\n'
bundle += policy_service + "\nend\n"
bundle += (ROOT / "tests/policy-service.luau").read_text()
# The real EconomyService with mocked services and a test-controlled os.clock.
economy_service = (ROOT / "src/server/Services/EconomyService.luau").read_text()
economy_service = re.sub(r'local (\w+) = require\([^\n]+\)', r'local \1 = dependencies.\1', economy_service)
bundle += "\nlocal function loadEconomyService(dependencies, game, clock)\n"
bundle += 'local os = { clock = clock }\nlocal script = { Parent = {} }\n'
bundle += economy_service + "\nend\n"
bundle += (ROOT / "tests/economy-service.luau").read_text()
with tempfile.TemporaryDirectory(prefix="golem-check-") as folder:
    path = Path(folder) / "regression.luau"
    path.write_text(bundle)
    result = subprocess.run([runner, str(path)], cwd=ROOT, capture_output=True, text=True)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    if result.returncode != 0:
        # On GitHub Actions, "::error::" lines become annotations on the PR, so
        # the failing assert shows without opening the log. Line numbers refer
        # to the bundle; the message says which test failed.
        if os.environ.get("GITHUB_ACTIONS"):
            for line in (result.stderr or result.stdout).strip().splitlines()[:8]:
                print(f"::error title=Regression tests::{line}")
        sys.exit(result.returncode)
print(f"Checked {len(files)} Luau files; Studio playtests are still required.")
