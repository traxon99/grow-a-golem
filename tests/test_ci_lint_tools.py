"""Pinned lint-tool install script stays aligned with GitHub release digests."""
import json
import os
import re
import unittest
import urllib.error
import urllib.request
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


def _release_asset_digest(repo: str, tag: str, asset_name: str) -> str:
    url = f"https://api.github.com/repos/{repo}/releases/tags/{tag}"
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "grow-a-golem-ci-tests",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        release = json.load(response)
    for asset in release.get("assets", []):
        if asset.get("name") == asset_name:
            digest = asset.get("digest", "")
            if digest.startswith("sha256:"):
                return digest.removeprefix("sha256:")
            raise AssertionError(f"release asset {asset_name} has no sha256 digest")
    raise AssertionError(f"asset {asset_name} not found on {repo} {tag}")


class CiLintTools(unittest.TestCase):
    def test_script_exists(self):
        self.assertTrue(SCRIPT.is_file())

    def test_release_digests_match_github(self):
        digests = re.findall(r"sha256:([0-9a-f]{64})", SCRIPT.read_text())
        self.assertEqual(len(digests), len(PINNED))
        for (repo, tag, asset_name), expected in zip(PINNED, digests, strict=True):
            try:
                live = _release_asset_digest(repo, tag, asset_name)
            except urllib.error.HTTPError as err:
                self.fail(f"GitHub API {err.code} for {repo} {tag}: {err.reason}")
            self.assertEqual(live, expected)
