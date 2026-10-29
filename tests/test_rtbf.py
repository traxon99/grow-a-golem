"""Offline tests for the owner-operated RTBF deletion helper."""
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
spec = importlib.util.spec_from_file_location("rtbf", ROOT / "scripts/rtbf.py")
rtbf = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rtbf)


class RTBFTests(unittest.TestCase):
    def test_store_discovery_and_targets(self):
        with tempfile.TemporaryDirectory() as folder:
            config = Path(folder) / "Config.luau"
            config.write_text(
                'Config.Data = {\n  storeName = "PlayerData_v1",\n}\n'
                'Config.Leaderboards = {\n  boards = {\n'
                '    { id = "a", store = "LB_A_v1" },\n'
                '    { id = "b", store = "LB_B_v1" },\n'
                '  },\n}\n',
                encoding="utf-8",
            )
            targets = rtbf.deletion_targets(456, 123, config)
        self.assertEqual([(store, key) for store, key, _ in targets], [
            ("PlayerData_v1", "player_123"),
            ("LB_A_v1", "123"),
            ("LB_B_v1", "123"),
        ])
        self.assertIn("/data-stores/PlayerData_v1/scopes/global/entries/player_123", targets[0][2])
        self.assertIn("/ordered-data-stores/LB_B_v1/scopes/global/entries/123", targets[2][2])

    def test_actual_config_is_readable(self):
        store, boards = rtbf.store_names(ROOT / "src/shared/Config.luau")
        self.assertEqual(store, "PlayerData_v1")
        self.assertEqual(boards, ["LB_Level_v1", "LB_Awakenings_v1", "LB_Artifacts_v1"])

    def test_dry_run_never_calls_network(self):
        output = io.StringIO()
        with patch.object(sys, "argv", ["rtbf.py", "123", "--universe-id", "456"]):
            with patch.object(rtbf, "urlopen", side_effect=AssertionError("network used")):
                with contextlib.redirect_stdout(output):
                    self.assertEqual(rtbf.main(), 0)
        self.assertIn("DRY RUN ONLY", output.getvalue())
        self.assertIn("LB_Artifacts_v1", output.getvalue())

    def test_execute_requires_matching_confirmation(self):
        with patch.object(sys, "argv", ["rtbf.py", "123", "--universe-id", "456", "--execute"]):
            with contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as caught:
                    rtbf.main()
        self.assertEqual(caught.exception.code, 2)

    def test_delete_request_and_throttle_retry(self):
        response = MagicMock()
        response.__enter__.return_value.status = 204
        too_many = HTTPError("https://example.test", 429, "Too Many Requests", {}, None)
        with patch.object(rtbf, "urlopen", side_effect=[too_many, response]) as call:
            with patch.object(rtbf.time, "sleep") as sleep:
                self.assertEqual(rtbf.delete_entry("https://example.test", "secret"), "deleted")
        self.assertEqual(call.call_count, 2)
        request = call.call_args_list[1].args[0]
        self.assertEqual(request.get_method(), "DELETE")
        self.assertEqual(request.get_header("X-api-key"), "secret")
        sleep.assert_called_once()


if __name__ == "__main__":
    unittest.main()
