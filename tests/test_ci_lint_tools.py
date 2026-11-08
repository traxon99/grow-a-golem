"""Pinned lint-tool install script stays aligned with GitHub release digests."""
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/ci_install_lint_tools.sh"

# Same order as download_release_zip calls in ci_install_lint_tools.sh.
PINNED = (
    ("rojo-rbx/rojo", "v7.6.1", "rojo-7.6.1-linux-x86_64.zip"),
    ("JohnnyMorganz/StyLua", "v2.6.0", "stylua-linux-x86_64.zip"),
    ("Kampfkarren/selene", "0.32.0", "selene-0.32.0-linux.zip"),
    ("JohnnyMorganz/luau-lsp", "1.70.0", "luau-lsp-linux-x86_64.zip"),
)


class CiLintTools(unittest.TestCase):
    def test_script_exists(self):
        self.assertTrue(SCRIPT.is_file())

    def test_release_digests_match_github(self):
        digests = re.findall(r"sha256:([0-9a-f]{64})", SCRIPT.read_text())
        self.assertEqual(len(digests), len(PINNED))
        for (repo, tag, asset_name), expected in zip(PINNED, digests, strict=True):
            out = subprocess.run(
                [
                    "gh",
                    "api",
                    f"repos/{repo}/releases/tags/{tag}",
                    "--jq",
                    f'.assets[] | select(.name=="{asset_name}") | .digest',
                ],
                capture_output=True,
                text=True,
                check=True,
            )
            digest = out.stdout.strip()
            self.assertTrue(digest.startswith("sha256:"), digest)
            self.assertEqual(digest.removeprefix("sha256:"), expected)
