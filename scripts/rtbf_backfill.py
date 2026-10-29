#!/usr/bin/env python3
"""One-time Open Cloud backfill: redact legacy trade partner UserIds from
every existing player save (#170, follow-up to #137 / PR #169).

The current build stops persisting trade partner UserIds and self-redacts
`trades.log[].with` / `trades.pending.with` the next time a save loads
(src/server/Services/DataService.luau's redactTradePartners). An inactive
player who never rejoins keeps the old value indefinitely, so this script
enumerates every entry in Config.Data.storeName (global scope, "player_"
keys only) and applies the same redaction directly through Open Cloud.

Dry run by default. Uses only the Python standard library and Roblox Open
Cloud v2. Run only after draining all live servers -- see docs/launch/
plan.md's RTBF section -- so no session is still saving over this script's
writes. As a backstop (a drain is a request, not a guarantee an expiring
lease has already lapsed everywhere), any entry whose `_session` lease
(src/shared/SessionLease.luau) has not yet expired is skipped and reported
rather than force-written; rerun once it's expired.

Every write is conditional on the version read moments before (an ETag
match), so a profile that changes between this script's read and write
is never blindly overwritten: the write is rejected, this script re-reads
the latest value and retries the redaction against it, up to --max-retries
times. Redaction is idempotent (an already-redacted record has no `with`
field left to remove), so a conflict retry, or rerunning this script
entirely, never double-applies or corrupts anything.

Safety notes for the owner before the first --execute:
  * Verify this script's assumed Open Cloud v2 wire details against
    Roblox's current Open Cloud reference before relying on them: the
    `ETag` response header as a read's version, `If-Match` on a
    conditional write, HTTP 409/412 for a version conflict, and the
    `dataStoreEntries` / `nextPageToken` fields on a list response. The
    API surface can change; this script isolates every such call in
    list_entries/get_entry/set_entry so a mismatch is a small, local fix.
  * Keep the API key outside the repository, as for scripts/rtbf.py.
  * Review the dry-run report (every store entry is read either way)
    before the first --execute, and keep the printed audit lines or
    --audit-log file as the record that the backfill ran and what it did.
"""
import argparse
import copy
import json
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
PLAYER_KEY_PREFIX = "player_"


class VersionConflict(Exception):
    """The entry changed since it was last read; the caller should re-fetch."""


def player_store_name(config_path: Path) -> str:
    """Resolve Config.Data.storeName, the same section scripts/rtbf.py reads."""
    source = config_path.read_text(encoding="utf-8")
    section = re.search(r"(?ms)^Config\.Data\s*=\s*\{.*?^\}", source)
    if not section:
        raise ValueError("Missing Config.Data in src/shared/Config.luau")
    match = re.search(r'\bstoreName\s*=\s*"([^"]+)"', section.group(0))
    if not match:
        raise ValueError("Could not resolve Config.Data.storeName")
    return match.group(1)


def redact(value: any) -> tuple[any, bool]:
    """Mirror DataService.luau's redactTradePartners. Never mutates `value`;
    returns (new_value, changed)."""
    if not isinstance(value, dict):
        return value, False
    result = copy.deepcopy(value)
    trades = result.get("trades")
    if not isinstance(trades, dict):
        return result, False
    changed = False
    log = trades.get("log")
    if isinstance(log, list):
        for entry in log:
            if isinstance(entry, dict) and "with" in entry:
                del entry["with"]
                changed = True
    pending = trades.get("pending")
    if isinstance(pending, dict) and "with" in pending:
        del pending["with"]
        changed = True
    return result, changed


def session_active(value: any, now: float) -> bool:
    """True if a lease (src/shared/SessionLease.luau's `_session`) hasn't
    expired yet -- a server may still be saving over this record."""
    if not isinstance(value, dict):
        return False
    session = value.get("_session")
    if not isinstance(session, dict):
        return False
    expires_at = session.get("expiresAt")
    return isinstance(expires_at, (int, float)) and expires_at > now


def _call(request: Request, retries: int = 3) -> tuple[int, any, bytes]:
    """Issue one request, retrying throttling/server failures with backoff,
    and return (status, headers, body) with the response already read and
    closed -- callers never hold a response object past this call, so
    there's nothing left open to read from twice. Raises RuntimeError on a
    permanent failure or exhausted retries, VersionConflict on 409/412."""
    for attempt in range(retries + 1):
        try:
            with urlopen(request, timeout=20) as response:
                return response.status, response.headers, response.read()
        except HTTPError as error:
            if error.code in (409, 412):
                raise VersionConflict() from error
            if error.code not in (429, 500, 502, 503, 504) or attempt == retries:
                raise RuntimeError(f"HTTP {error.code}: {error.reason}") from error
        except (URLError, TimeoutError) as error:
            if attempt == retries:
                raise RuntimeError(f"Network error: {error}") from error
        time.sleep(min(2**attempt, 8))
    raise AssertionError("unreachable")


def list_entries(
    universe_id: int, store: str, api_key: str, page_token: str | None = None, max_page_size: int = 100
) -> tuple[list[str], str | None]:
    url = f"{BASE_URL}/{universe_id}/data-stores/{quote(store, safe='')}/scopes/global/entries"
    url += f"?maxPageSize={max_page_size}&prefix={quote(PLAYER_KEY_PREFIX, safe='')}"
    if page_token:
        url += f"&pageToken={quote(page_token, safe='')}"
    request = Request(url, headers={"x-api-key": api_key}, method="GET")
    _, _, raw_body = _call(request)
    body = json.loads(raw_body)
    entries = [entry["id"] for entry in body.get("dataStoreEntries", [])]
    return entries, body.get("nextPageToken") or None


def get_entry(universe_id: int, store: str, entry_id: str, api_key: str) -> tuple[any, str]:
    url = (
        f"{BASE_URL}/{universe_id}/data-stores/{quote(store, safe='')}/scopes/global/"
        f"entries/{quote(entry_id, safe='')}"
    )
    request = Request(url, headers={"x-api-key": api_key}, method="GET")
    _, headers, raw_body = _call(request)
    version = headers.get("ETag")
    value = json.loads(raw_body)
    return value, version


def set_entry(universe_id: int, store: str, entry_id: str, api_key: str, value: any, match_version: str) -> None:
    """Writes only if the live entry's version still matches match_version;
    raises VersionConflict (never silently overwrites) if it doesn't."""
    url = (
        f"{BASE_URL}/{universe_id}/data-stores/{quote(store, safe='')}/scopes/global/"
        f"entries/{quote(entry_id, safe='')}"
    )
    headers = {"x-api-key": api_key, "Content-Type": "application/json", "If-Match": match_version}
    request = Request(url, data=json.dumps(value).encode("utf-8"), headers=headers, method="PATCH")
    _call(request)


def process_entry(
    universe_id: int,
    store: str,
    entry_id: str,
    api_key: str,
    execute: bool,
    now: float,
    max_retries: int,
) -> dict:
    """Reads one entry, redacts it, and (if --execute) writes it back with
    conflict-safe retries. Returns one audit record; never raises for a
    single entry's ordinary failure modes (they're reported, not fatal)."""
    record = {"entry": entry_id}
    try:
        value, version = get_entry(universe_id, store, entry_id, api_key)
    except RuntimeError as error:
        record.update(status="failed", detail=str(error))
        return record

    if session_active(value, now):
        record.update(status="skipped_active_session")
        return record

    new_value, changed = redact(value)
    if not changed:
        record.update(status="already_clean")
        return record

    if not execute:
        record.update(status="would_redact")
        return record

    for attempt in range(max_retries + 1):
        try:
            set_entry(universe_id, store, entry_id, api_key, new_value, version)
            record.update(status="redacted", attempts=attempt + 1)
            return record
        except VersionConflict:
            if attempt == max_retries:
                record.update(status="conflict_exhausted", attempts=attempt + 1)
                return record
            try:
                value, version = get_entry(universe_id, store, entry_id, api_key)
            except RuntimeError as error:
                record.update(status="failed", detail=str(error), attempts=attempt + 1)
                return record
            if session_active(value, now):
                record.update(status="skipped_active_session", attempts=attempt + 1)
                return record
            new_value, changed = redact(value)
            if not changed:
                # Someone else's write already redacted it -- idempotent no-op.
                record.update(status="already_clean", attempts=attempt + 1)
                return record
        except RuntimeError as error:
            record.update(status="failed", detail=str(error), attempts=attempt + 1)
            return record
    raise AssertionError("unreachable")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--universe-id", type=int, required=True, help="Experience universe ID (not place ID)")
    parser.add_argument("--execute", action="store_true", help="Actually write redactions; default is dry-run")
    parser.add_argument(
        "--confirm-execute",
        action="store_true",
        help="Required with --execute, as a second explicit flag (there's no single UserId to echo back here)",
    )
    parser.add_argument("--max-entries", type=int, default=None, help="Stop after this many entries (testing)")
    parser.add_argument("--max-retries", type=int, default=3, help="Conflict-retry attempts per entry")
    parser.add_argument("--sleep-seconds", type=float, default=0.25, help="Delay between entries")
    parser.add_argument("--page-size", type=int, default=100)
    parser.add_argument("--audit-log", type=Path, default=None, help="Append one JSON line per entry here")
    parser.add_argument("--config", type=Path, default=ROOT / "src/shared/Config.luau")
    args = parser.parse_args()

    if args.universe_id <= 0:
        parser.error("--universe-id must be a positive integer")
    if args.execute and not args.confirm_execute:
        parser.error("--execute requires --confirm-execute")

    try:
        store = player_store_name(args.config)
    except (OSError, ValueError) as error:
        print(f"Configuration error: {error}", file=sys.stderr)
        return 1

    api_key = os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY")
    if not api_key:
        print("ROBLOX_OPEN_CLOUD_API_KEY is required", file=sys.stderr)
        return 1

    mode = "EXECUTE" if args.execute else "DRY RUN"
    print(f"{mode}: backfilling {store!r} (universe {args.universe_id}, global scope, '{PLAYER_KEY_PREFIX}*' keys)")

    audit = args.audit_log.open("a", encoding="utf-8") if args.audit_log else None
    counts: dict[str, int] = {}
    failed = False
    now = time.time()
    processed = 0
    page_token = None

    try:
        while True:
            try:
                entries, page_token = list_entries(args.universe_id, store, api_key, page_token, args.page_size)
            except RuntimeError as error:
                print(f"Listing entries failed: {error}", file=sys.stderr)
                return 1
            for entry_id in entries:
                if args.max_entries is not None and processed >= args.max_entries:
                    page_token = None
                    break
                record = process_entry(
                    args.universe_id, store, entry_id, api_key, args.execute, now, args.max_retries
                )
                counts[record["status"]] = counts.get(record["status"], 0) + 1
                if record["status"] in ("failed", "conflict_exhausted"):
                    failed = True
                print(f"  {entry_id}: {record['status']}" + (f" ({record['detail']})" if "detail" in record else ""))
                if audit:
                    audit.write(json.dumps(record) + "\n")
                    audit.flush()
                processed += 1
                time.sleep(args.sleep_seconds)
            if not page_token:
                break
    finally:
        if audit:
            audit.close()

    print(f"Processed {processed} entries: {counts}")
    if not args.execute:
        print("DRY RUN ONLY. No data changed. Use --execute and --confirm-execute to apply.")
        return 0
    if failed:
        print("Some entries failed or exhausted their retries; rerun is safe (redaction is idempotent).", file=sys.stderr)
        return 1
    print("Backfill complete. Record the result alongside the RTBF audit log.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
