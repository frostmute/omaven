"""Regression tests for Aven TUI launcher argument handling."""
import importlib.machinery
import importlib.util
from pathlib import Path
import shlex
import unittest
from unittest.mock import patch

BACKEND = Path(__file__).resolve().parents[1] / "bin" / "aven-backend"
loader = importlib.machinery.SourceFileLoader("aven_backend", str(BACKEND))
spec = importlib.util.spec_from_loader(loader.name, loader)
backend = importlib.util.module_from_spec(spec)
loader.exec_module(backend)


class TuiLaunchTests(unittest.TestCase):
    def check_launcher(self, project, launcher):
        with patch.object(backend.sys, "argv", ["aven-backend", "tui", project]), \
             patch.object(backend.shutil, "which", side_effect=lambda name: "/usr/bin/" + name if name == launcher else None), \
             patch.object(backend.subprocess, "Popen") as popen, \
             patch.object(backend, "AVEN_BIN", "/usr/bin/aven"):
            backend.cmd_tui()
            argv = popen.call_args.args[0]
            expected = ["/usr/bin/aven", "tui"] + (["-p", project] if project else [])
            if launcher == "omarchy-launch-floating-terminal-with-presentation":
                self.assertEqual(shlex.split(argv[1]), expected)
                self.assertEqual(len(argv), 2)
            else:
                self.assertEqual(argv, [launcher, "-e", *expected])

    def test_project_keys_are_literal_arguments(self):
        for project in ("normal", "with spaces", "x; touch /tmp/should-not-run", "$(id)", "a'b", "a\"b", ""):
            for launcher in ("omarchy-launch-floating-terminal-with-presentation", "ghostty", "foot", "alacritty"):
                with self.subTest(project=project, launcher=launcher):
                    self.check_launcher(project, launcher)


if __name__ == "__main__":
    unittest.main()
