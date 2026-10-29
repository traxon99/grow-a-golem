#!/usr/bin/env python3
"""Delete one Roblox user's progress and leaderboard entries (RTBF).

Dry run by default. Uses only the Python standard library and Roblox Open
Cloud v2. Run after draining old game servers, with an API key supplied via
ROBLOX_OPEN_CLOUD_API_KEY. This tool does not discover other data stores.
"""
import argparse
import os
from pathlib import Path
import re
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
BASE_URL = "https://apis.roblox.com/cloud/v2/universes"


def config_section(source: str, name: str) -> str:
    """Find a top-level Config section, including its nested tables."""
    match = re.search(r"(?ms)^Config\." + re.escape(name) + r"\s*=\s*\{.*?^\}", source)
    if not match:
        raise ValueError(f"Missing Config.{name} in src/shared/Config.luau")
    return match.group(0)


def store_names(config_path: Path) -> tuple[str, list[str]]:
    source = config_path.read_text(encoding="utf-8")
    data = config_section(source, "Data")
    boards = config_section(source, "Leaderboards")
    match = re.search(r'\bstoreName\s*=\s*"([^"]+)"', data)
    names = re.findall(r'\bstore\s*=\s*"([^"]+)"', boards)
    if not match or not names or len(set(names)) != len(names):
        raise ValueError("Could not uniquely resolve player and leaderboard stores from Config")
    return match.group(1), names


def deletion_targets(universe_id: int, user_id: int, config_path: Path) -> list[tuple[str, str, str]]:
    player_store, board_stores = store_names(config_path)
    prefix = f"{BASE_URL}/{universe_id}"
    targets = [
        (
            player_store,
            f"player_{user_id}",
            f"{prefix}/data-stores/{quote(player_store, safe='')}/scopes/global/"
            f"entries/{quote(f'player_{user_id}', safe='')}",
        )
    ]
    for store in board_stores:
        targets.append(
            (
                store,
                str(user_id),
                f"{prefix}/ordered-data-stores/{quote(store, safe='')}/scopes/global/entries/{user_id}",
            )
        )
    return targets


def delete_entry(url: str, api_key: str) -> str:
    """Retry throttling/server failures; never retry a permanent auth error."""
    for attempt in range(4):
        try:
            request = Request(url, headers={"x-api-key": api_key}, method="DELETE")
            with urlopen(request, timeout=20) as response:
                if response.status in (200, 204):
                    return "deleted"
                raise RuntimeError(f"Unexpected HTTP {response.status}")
        except HTTPError as error:
            if error.code == 404:
                return "not found (verify the store/scope if unexpected)"
            if error.code not in (429, 500, 502, 503, 504) or attempt == 3:
                raise RuntimeError(f"HTTP {error.code}: {error.reason}") from error
        except (URLError, TimeoutError) as error:
            if attempt == 3:
                raise RuntimeError(f"Network error: {error}") from error
        time.sleep(min(2 ** attempt, 8))
    raise AssertionError("unreachable")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("user_id", type=int, help="UserId from a verified Roblox RTBF request")
    parser.add_argument("--universe-id", type=int, required=True, help="Experience universe ID (not place ID)")
    parser.add_argument("--execute", action="store_true", help="Actually delete entries; default is dry-run")
    parser.add_argument(
        "--confirm-user-id",
        type=int,
        help="Required with --execute; must exactly match the target UserId",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=ROOT / "src/shared/Config.luau",
        help="Path to the deployed Config.luau",
    )
    args = parser.parse_args()
    if args.user_id <= 0 or args.universe_id <= 0:
        parser.error("UserId and universe ID must be positive integers")
    if args.execute and args.confirm_user_id != args.user_id:
        parser.error("--execute requires --confirm-user-id matching the target UserId")

    try:
        targets = deletion_targets(args.universe_id, args.user_id, args.config)
    except (OSError, ValueError) as error:
        print(f"Configuration error: {error}", file=sys.stderr)
        return 1

    print(f"Universe {args.universe_id}: {len(targets)} deletion targets for UserId {args.user_id}")
    for store, key, _ in targets:
        print(f"  {store} / global / {key}")

    if not args.execute:
        print("DRY RUN ONLY. No data deleted. Use --execute and --confirm-user-id to apply.")
        return 0

    api_key = os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY")
    if not api_key:
        print("ROBLOX_OPEN_CLOUD_API_KEY is required for --execute", file=sys.stderr)
        return 1

    failed = False
    for store, key, url in targets:
        try:
            result = delete_entry(url, api_key)
            print(f"{store}/{key}: {result}")
        except RuntimeError as error:
            failed = True
            print(f"{store}/{key}: FAILED ({error})", file=sys.stderr)
        time.sleep(0.25)  # leave headroom for live DataStore requests

    if failed:
        print("Some deletions failed. Resolve permissions/availability and rerun.", file=sys.stderr)
        return 1
    print("All deletion requests completed. Record the result in the private RTBF audit log.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
