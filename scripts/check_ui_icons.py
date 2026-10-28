#!/usr/bin/env python3
"""Exercise the real client sprite renderer with lightweight Roblox value stubs."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'src/client/Icons.luau').read_text()
# Inject only engine dependencies; execute the production renderer unchanged.
source = source[source.index('local Icons = {}'):]
config = (ROOT / 'src/shared/Config.luau').read_text()
registry = config[config.index('Config.UiIcons = {'):config.rindex('return Config')]
tests = (ROOT / 'tests/ui-icons.luau').read_text()
bundle = 'local Config = {}\n' + registry + '\nlocal function loadIcons(Instance, Enum, Color3, Vector2, UDim2)\n' + source + '\nend\n' + tests
with tempfile.TemporaryDirectory(prefix='golem-ui-icons-') as directory:
    test = Path(directory) / 'ui-icons.luau'
    test.write_text(bundle)
    subprocess.run([os.environ.get('LUAU', 'luau'), str(test)], check=True, cwd=ROOT)
