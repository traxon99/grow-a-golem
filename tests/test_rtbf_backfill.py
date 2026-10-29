"""Offline tests for the owner-operated legacy-trade-partner backfill (#170).

Mirrors tests/test_rtbf.py's style: load the script by path, patch its
`urlopen` to avoid any real network call, and drive main()/the per-entry
helpers directly.
"""
import contextlib
import importlib.util
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch, MagicMock
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("rtbf_backfill", ROOT / "scripts/rtbf_backfill.py")
rtbf_backfill = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rtbf_backfill)


def _response(body: dict, headers: dict | None = None, status: int = 200) -> MagicMock:
    import json

    response = MagicMock()
    response.__enter__.return_value.status = status
    response.__enter__.return_value.read.return_value = json.dumps(body).encode("utf-8")
    response.__enter__.return_value.headers = headers or {}
    return response


class RedactionTests(unittest.TestCase):
    """The pure redaction logic, independent of any HTTP call."""

    def test_redacts_log_and_pending_without_mutating_the_input(self):
        value = {"trades": {"log": [{"with": 123, "at": 1}, {"at": 2}], "pending": {"with": 456, "item": "x"}}}
        new_value, changed = rtbf_backfill.redact(value)
        self.assertTrue(changed)
        self.assertNotIn("with", new_value["trades"]["log"][0])
        self.assertNotIn("with", new_value["trades"]["pending"])
        self.assertEqual(new_value["trades"]["log"][1], {"at": 2})
        # The input dict itself is untouched -- a caller can safely retry
        # a redaction against the same originally-read value.
        self.assertEqual(value["trades"]["log"][0]["with"], 123)
        self.assertEqual(value["trades"]["pending"]["with"], 456)

    def test_already_clean_record_is_unchanged(self):
        value = {"trades": {"log": [{"at": 1}], "pending": {"item": "x"}}}
        new_value, changed = rtbf_backfill.redact(value)
        self.assertFalse(changed)
        self.assertEqual(new_value, value)

    def test_redaction_is_idempotent(self):
        value = {"trades": {"log": [{"with": 123}], "pending": {"with": 456}}}
        once, _ = rtbf_backfill.redact(value)
        twice, changed_again = rtbf_backfill.redact(once)
        self.assertFalse(changed_again)
        self.assertEqual(once, twice)

    def test_records_with_no_trades_table_are_untouched(self):
        for value in ({"golem": {}}, {"trades": "not a table"}, {}, "not a dict", None):
            new_value, changed = rtbf_backfill.redact(value)
            self.assertFalse(changed, f"unexpected change for {value!r}")
            self.assertEqual(new_value, value)


class SessionActiveTests(unittest.TestCase):
    def test_future_expiry_is_active(self):
        self.assertTrue(rtbf_backfill.session_active({"_session": {"expiresAt": 1000}}, 500))

    def test_past_expiry_is_not_active(self):
        self.assertFalse(rtbf_backfill.session_active({"_session": {"expiresAt": 500}}, 1000))

    def test_no_session_is_not_active(self):
        self.assertFalse(rtbf_backfill.session_active({}, 1000))
        self.assertFalse(rtbf_backfill.session_active("not a dict", 1000))


class DiscoveryTests(unittest.TestCase):
    def test_store_name_matches_the_real_config(self):
        self.assertEqual(rtbf_backfill.player_store_name(ROOT / "src/shared/Config.luau"), "PlayerData_v1")

    def test_list_entries_reads_ids_and_the_next_page_token(self):
        body = {"dataStoreEntries": [{"id": "player_1"}, {"id": "player_2"}], "nextPageToken": "abc"}
        with patch.object(rtbf_backfill, "urlopen", return_value=_response(body)) as call:
            entries, next_token = rtbf_backfill.list_entries(999, "PlayerData_v1", "key")
        self.assertEqual(entries, ["player_1", "player_2"])
        self.assertEqual(next_token, "abc")
        request = call.call_args.args[0]
        self.assertIn("/data-stores/PlayerData_v1/scopes/global/entries", request.full_url)
        self.assertIn("prefix=player_", request.full_url)

    def test_list_entries_with_no_more_pages_returns_none(self):
        body = {"dataStoreEntries": [{"id": "player_1"}]}
        with patch.object(rtbf_backfill, "urlopen", return_value=_response(body)):
            _, next_token = rtbf_backfill.list_entries(999, "PlayerData_v1", "key")
        self.assertIsNone(next_token)

    def test_get_entry_reads_the_value_and_its_version(self):
        body = {"trades": {"pending": {"with": 1}}}
        with patch.object(rtbf_backfill, "urlopen", return_value=_response(body, headers={"ETag": "v1"})):
            value, version = rtbf_backfill.get_entry(999, "PlayerData_v1", "player_1", "key")
        self.assertEqual(value, body)
        self.assertEqual(version, "v1")


class SetEntryTests(unittest.TestCase):
    def test_set_entry_sends_if_match_with_the_given_version(self):
        with patch.object(rtbf_backfill, "urlopen", return_value=_response({}, status=200)) as call:
            rtbf_backfill.set_entry(999, "PlayerData_v1", "player_1", "key", {"trades": {}}, "v1")
        request = call.call_args.args[0]
        self.assertEqual(request.get_method(), "PATCH")
        self.assertEqual(request.get_header("If-match"), "v1")

    def test_set_entry_raises_version_conflict_on_412(self):
        conflict = HTTPError("https://example.test", 412, "Precondition Failed", {}, None)
        with patch.object(rtbf_backfill, "urlopen", side_effect=conflict):
            with self.assertRaises(rtbf_backfill.VersionConflict):
                rtbf_backfill.set_entry(999, "PlayerData_v1", "player_1", "key", {}, "stale")

    def test_set_entry_raises_version_conflict_on_409(self):
        conflict = HTTPError("https://example.test", 409, "Conflict", {}, None)
        with patch.object(rtbf_backfill, "urlopen", side_effect=conflict):
            with self.assertRaises(rtbf_backfill.VersionConflict):
                rtbf_backfill.set_entry(999, "PlayerData_v1", "player_1", "key", {}, "stale")

    def test_throttling_retries_then_succeeds(self):
        too_many = HTTPError("https://example.test", 429, "Too Many Requests", {}, None)
        ok = _response({}, status=200)
        with patch.object(rtbf_backfill, "urlopen", side_effect=[too_many, ok]):
            with patch.object(rtbf_backfill.time, "sleep"):
                rtbf_backfill.set_entry(999, "PlayerData_v1", "player_1", "key", {}, "v1")  # does not raise


class ProcessEntryTests(unittest.TestCase):
    """process_entry() is where discovery, redaction, the active-session
    guard and conflict retries all meet, so it's covered directly rather
    than only indirectly through main()."""

    def test_already_clean_entry_is_reported_and_never_written(self):
        clean = {"trades": {"log": [{"at": 1}]}}
        with patch.object(rtbf_backfill, "get_entry", return_value=(clean, "v1")):
            with patch.object(rtbf_backfill, "set_entry") as set_call:
                record = rtbf_backfill.process_entry(1, "S", "player_1", "key", True, now=0, max_retries=3)
        self.assertEqual(record["status"], "already_clean")
        set_call.assert_not_called()

    def test_dry_run_reports_without_writing(self):
        dirty = {"trades": {"pending": {"with": 1}}}
        with patch.object(rtbf_backfill, "get_entry", return_value=(dirty, "v1")):
            with patch.object(rtbf_backfill, "set_entry") as set_call:
                record = rtbf_backfill.process_entry(1, "S", "player_1", "key", False, now=0, max_retries=3)
        self.assertEqual(record["status"], "would_redact")
        set_call.assert_not_called()

    def test_active_session_is_skipped_rather_than_overwritten(self):
        live = {"trades": {"pending": {"with": 1}}, "_session": {"expiresAt": 1000}}
        with patch.object(rtbf_backfill, "get_entry", return_value=(live, "v1")):
            with patch.object(rtbf_backfill, "set_entry") as set_call:
                record = rtbf_backfill.process_entry(1, "S", "player_1", "key", True, now=500, max_retries=3)
        self.assertEqual(record["status"], "skipped_active_session")
        set_call.assert_not_called()

    def test_execute_writes_the_redacted_value(self):
        dirty = {"trades": {"pending": {"with": 1}}}
        with patch.object(rtbf_backfill, "get_entry", return_value=(dirty, "v1")):
            with patch.object(rtbf_backfill, "set_entry") as set_call:
                record = rtbf_backfill.process_entry(1, "S", "player_1", "key", True, now=0, max_retries=3)
        self.assertEqual(record["status"], "redacted")
        self.assertEqual(record["attempts"], 1)
        written_value = set_call.call_args.args[4]
        self.assertNotIn("with", written_value["trades"]["pending"])
        self.assertEqual(set_call.call_args.args[5], "v1", "the write is conditioned on the version just read")

    def test_version_conflict_refetches_and_retries(self):
        """Someone else wrote the record between read and write: the retry
        re-reads the now-current value and redacts THAT, rather than
        blindly forcing the stale write through."""
        stale = {"trades": {"pending": {"with": 1}}}
        fresh = {"trades": {"pending": {"with": 2}}, "other": "field preserved"}
        with patch.object(rtbf_backfill, "get_entry", side_effect=[(stale, "v1"), (fresh, "v2")]):
            with patch.object(rtbf_backfill, "set_entry", side_effect=[rtbf_backfill.VersionConflict(), None]):
                record = rtbf_backfill.process_entry(1, "S", "player_1", "key", True, now=0, max_retries=3)
        self.assertEqual(record["status"], "redacted")
        self.assertEqual(record["attempts"], 2)

    def test_conflict_resolved_by_someone_else_s_redaction_is_reported_clean(self):
        """The record that conflicted turns out, on re-read, to already be
        redacted (someone else's write got there first) -- idempotent, so
        this is reported as already_clean rather than retried forever."""
        stale = {"trades": {"pending": {"with": 1}}}
        already_redacted = {"trades": {"pending": {}}}
        with patch.object(rtbf_backfill, "get_entry", side_effect=[(stale, "v1"), (already_redacted, "v2")]):
            with patch.object(rtbf_backfill, "set_entry", side_effect=[rtbf_backfill.VersionConflict()]):
                record = rtbf_backfill.process_entry(1, "S", "player_1", "key", True, now=0, max_retries=3)
        self.assertEqual(record["status"], "already_clean")

    def test_conflict_exhausts_retries_without_crashing(self):
        dirty = {"trades": {"pending": {"with": 1}}}
        with patch.object(rtbf_backfill, "get_entry", return_value=(dirty, "v1")):
            with patch.object(rtbf_backfill, "set_entry", side_effect=rtbf_backfill.VersionConflict()):
                record = rtbf_backfill.process_entry(1, "S", "player_1", "key", True, now=0, max_retries=2)
        self.assertEqual(record["status"], "conflict_exhausted")
        self.assertEqual(record["attempts"], 3)  # the initial attempt plus 2 retries

    def test_get_failure_is_reported_not_raised(self):
        with patch.object(rtbf_backfill, "get_entry", side_effect=RuntimeError("HTTP 500: boom")):
            record = rtbf_backfill.process_entry(1, "S", "player_1", "key", True, now=0, max_retries=3)
        self.assertEqual(record["status"], "failed")
        self.assertIn("boom", record["detail"])

    def test_rerunning_an_already_redacted_entry_is_a_safe_no_op(self):
        """The whole-script idempotence property: run process_entry twice
        in a row on the same record and the second run never writes."""
        value = {"trades": {"pending": {"with": 1}}}
        with patch.object(rtbf_backfill, "get_entry", return_value=(value, "v1")) as get_call:
            with patch.object(rtbf_backfill, "set_entry") as set_call:
                first = rtbf_backfill.process_entry(1, "S", "player_1", "key", True, now=0, max_retries=3)
        self.assertEqual(first["status"], "redacted")
        redacted_value = set_call.call_args.args[4]

        get_call.return_value = (redacted_value, "v2")
        with patch.object(rtbf_backfill, "get_entry", return_value=(redacted_value, "v2")):
            with patch.object(rtbf_backfill, "set_entry") as set_call_again:
                second = rtbf_backfill.process_entry(1, "S", "player_1", "key", True, now=0, max_retries=3)
        self.assertEqual(second["status"], "already_clean")
        set_call_again.assert_not_called()


class MainTests(unittest.TestCase):
    def test_dry_run_never_writes_and_walks_every_page(self):
        pages = [
            ({"dataStoreEntries": [{"id": "player_1"}], "nextPageToken": "p2"}),
            ({"dataStoreEntries": [{"id": "player_2"}]}),
        ]
        responses = [_response(page) for page in pages]
        entry_value = _response({"trades": {"pending": {"with": 1}}}, headers={"ETag": "v1"})

        def urlopen_side_effect(request, timeout=20):
            if "entries?" in request.full_url or "&pageToken=" in request.full_url:
                return responses.pop(0)
            return entry_value

        output = io.StringIO()
        os_environ = {"ROBLOX_OPEN_CLOUD_API_KEY": "key"}
        with patch.object(sys, "argv", ["rtbf_backfill.py", "--universe-id", "999"]):
            with patch.dict("os.environ", os_environ):
                with patch.object(rtbf_backfill, "urlopen", side_effect=urlopen_side_effect):
                    with patch.object(rtbf_backfill.time, "sleep"):
                        with contextlib.redirect_stdout(output):
                            code = rtbf_backfill.main()
        self.assertEqual(code, 0)
        self.assertIn("DRY RUN ONLY", output.getvalue())
        self.assertIn("player_1: would_redact", output.getvalue())
        self.assertIn("player_2: would_redact", output.getvalue())

    def test_execute_requires_confirm_execute_flag(self):
        with patch.object(sys, "argv", ["rtbf_backfill.py", "--universe-id", "999", "--execute"]):
            with contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as caught:
                    rtbf_backfill.main()
        self.assertEqual(caught.exception.code, 2)

    def test_missing_api_key_is_a_clean_failure(self):
        with patch.object(sys, "argv", ["rtbf_backfill.py", "--universe-id", "999"]):
            with patch.dict("os.environ", {}, clear=True):
                with contextlib.redirect_stderr(io.StringIO()) as err:
                    code = rtbf_backfill.main()
        self.assertEqual(code, 1)
        self.assertIn("ROBLOX_OPEN_CLOUD_API_KEY", err.getvalue())

    def test_audit_log_gets_one_line_per_entry(self):
        import json

        list_response = _response({"dataStoreEntries": [{"id": "player_1"}]})
        entry_response = _response({"trades": {"pending": {"with": 1}}}, headers={"ETag": "v1"})
        write_response = _response({}, status=200)

        with tempfile.TemporaryDirectory() as folder:
            audit_path = Path(folder) / "audit.jsonl"
            with patch.object(
                sys, "argv", ["rtbf_backfill.py", "--universe-id", "999", "--execute", "--confirm-execute",
                              "--audit-log", str(audit_path)],
            ):
                with patch.dict("os.environ", {"ROBLOX_OPEN_CLOUD_API_KEY": "key"}):
                    with patch.object(
                        rtbf_backfill, "urlopen", side_effect=[list_response, entry_response, write_response]
                    ):
                        with patch.object(rtbf_backfill.time, "sleep"):
                            with contextlib.redirect_stdout(io.StringIO()):
                                code = rtbf_backfill.main()
            lines = audit_path.read_text(encoding="utf-8").strip().splitlines()
        self.assertEqual(code, 0)
        self.assertEqual(len(lines), 1)
        record = json.loads(lines[0])
        self.assertEqual(record["entry"], "player_1")
        self.assertEqual(record["status"], "redacted")


if __name__ == "__main__":
    unittest.main()
