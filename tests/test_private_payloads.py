"""Exercise private task and note transport against an isolated Aven database."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

BACKEND = Path(__file__).resolve().parents[1] / "bin" / "aven-backend"
AVEN = shutil.which("aven") or str(Path.home() / ".local/bin/aven")


@unittest.skipUnless(Path(AVEN).is_file(), "Aven CLI required")
class PrivatePayloadTests(unittest.TestCase):
    def test_task_and_note_stay_out_of_command_lines(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            db = root / "tasks.db"
            log = root / "cmdlines"
            wrapper = root / "aven"
            wrapper.write_text(
                '#!/bin/sh\n'
                'cat /proc/$PPID/cmdline >> "$OMAVEN_TEST_LOG"\n'
                'cat /proc/$$/cmdline >> "$OMAVEN_TEST_LOG"\n'
                'exec "$OMAVEN_TEST_AVEN" --db "$OMAVEN_TEST_DB" "$@"\n'
            )
            wrapper.chmod(0o700)
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ["PATH"],
                       OMAVEN_TEST_LOG=str(log), OMAVEN_TEST_AVEN=AVEN, OMAVEN_TEST_DB=str(db))

            def call(args, payload):
                result = subprocess.run([str(BACKEND), *args], input=json.dumps(payload) + "\n",
                                        text=True, capture_output=True, env=env, timeout=25, check=True)
                return json.loads(result.stdout)

            title = 'private title "☃"\nsecond line'
            note = 'private note "雪"\nsecond line'
            created = call(["add", "--status", "active", "--priority", "high"], title)
            self.assertTrue(created["ok"], created)
            task = json.loads(created["message"][0]["text"])["task"]
            self.assertEqual((task["title"], task["status"], task["priority"]), (title, "active", "high"))
            added = call(["note", task["ref"]], note)
            self.assertTrue(added["ok"], added)
            shown = subprocess.run([AVEN, "--db", str(db), "show", task["ref"], "--full", "--json"],
                                   capture_output=True, text=True, check=True)
            self.assertIn(note, shown.stdout.replace('\\n', '\n').replace('\\"', '"'))
            self.assertNotIn(title.encode(), log.read_bytes())
            self.assertNotIn(note.encode(), log.read_bytes())
            failed = call(["add", "--project", "no-such-project"], title)
            self.assertFalse(failed["ok"], failed)


if __name__ == "__main__":
    unittest.main()
