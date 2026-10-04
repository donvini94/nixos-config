"""Check writable Pi settings, isolated state and dependency refresh without network access."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(sys.argv.pop(1)).resolve()
BASH = shutil.which("bash")
assert BASH is not None, "Tests require Bash"


class BootstrapPiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.agent = self.root / ".pi/agent"
        self.agent.mkdir(parents=True)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.calls = self.root / "npm-calls"
        for name, text in {
            "pi": f"#!{BASH}\nprintf '1.0.0\\n'\n",
            "npm": f'#!{BASH}\necho "$*" >> "{self.calls}"\nmkdir -p node_modules\n',
        }.items():
            command = self.bin / name
            command.write_text(text)
            command.chmod(0o755)
        self.env = dict(
            os.environ,
            HOME=str(self.root),
            PI_AGENT_DIR=str(self.agent),
            PI_VERSION="1.0.0",
        )
        self.env["PATH"] = f"{self.bin}{os.pathsep}{self.env['PATH']}"
        declarations = {
            "PI_DEFAULT_SETTINGS": {
                "packages": ["managed"],
                "defaultModel": "default",
                "defaultTools": ["read"],
            },
            "PI_DECLARED_MODELS": {
                "providers": {"managed": {"baseUrl": "https://declared.invalid"}}
            },
            "PI_DECLARED_SUBAGENTS": {
                "promptInheritance": {"claude-bridge": "portable"}
            },
            "PI_WEB_PACKAGE": {"name": "fixture"},
            "PI_WEB_LOCK": {"lockfileVersion": 3},
        }
        for variable, value in declarations.items():
            file = self.root / variable
            file.write_text(json.dumps(value))
            self.env[variable] = str(file)
        index = self.root / "index.ts"
        index.write_text("export default () => {};\n")
        self.env["PI_WEB_INDEX"] = str(index)

    def invoke(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(SCRIPT)],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )

    def test_initial_defaults_and_repeat_activation(self) -> None:
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        settings = json.loads((self.agent / "settings.json").read_text())
        self.assertEqual(settings["packages"], ["managed"])
        self.assertEqual((self.agent / "settings.json").stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.invoke().returncode, 0)
        self.assertEqual(self.calls.read_text().splitlines(), ["ci --ignore-scripts"])
        Path(self.env["PI_WEB_LOCK"]).write_text(
            '{"lockfileVersion": 3, "changed": true}'
        )
        self.assertEqual(self.invoke().returncode, 0)
        self.assertEqual(len(self.calls.read_text().splitlines()), 2)

    def test_native_settings_and_other_client_state_are_preserved(self) -> None:
        settings = {
            "packages": ["native"],
            "extensions": ["custom.ts"],
            "defaultModel": "chosen",
            "skills": ["personal"],
        }
        (self.agent / "settings.json").write_text(json.dumps(settings))
        (self.agent / "models.json").write_text(
            json.dumps(
                {
                    "providers": {
                        "personal": {"baseUrl": "https://personal.invalid"},
                        "managed": {"baseUrl": "https://old.invalid"},
                    }
                }
            )
        )
        state = [
            self.agent / name
            for name in ("mcp.json", "AGENTS.md", "MEMORY.md", "auth.json")
        ]
        state.append(self.root / ".omp/agent/config.yml")
        for file in state:
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text("private fixture\n")
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        actual = json.loads((self.agent / "settings.json").read_text())
        self.assertEqual(actual, settings | {"defaultTools": ["read"]})
        providers = json.loads((self.agent / "models.json").read_text())["providers"]
        self.assertEqual(providers["managed"]["baseUrl"], "https://declared.invalid")
        self.assertIn("personal", providers)
        for file in state:
            self.assertEqual(file.read_text(), "private fixture\n")

    def test_bridge_compatibility_preserves_subagent_settings(self) -> None:
        file = self.agent / "subagents.json"
        expected = {"promptInheritance": {"claude-bridge": "portable"}}
        self.assertEqual(self.invoke().returncode, 0)
        self.assertEqual(json.loads(file.read_text()), expected)
        file.write_text(
            json.dumps(
                {
                    "maxConcurrent": 2,
                    "promptInheritance": {"claude-bridge": "full", "other": "full"},
                }
            )
        )
        expected["promptInheritance"]["other"] = "full"
        expected["maxConcurrent"] = 2
        for _ in range(2):
            result = self.invoke()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(file.read_text()), expected)
            self.assertEqual(file.stat().st_mode & 0o777, 0o600)

    def test_requesty_provider_gets_key_and_keeps_discovered_models(self) -> None:
        key = self.root / "key"
        key.write_text("secret-value\n")
        self.env["PI_REQUESTY_KEY_FILE"] = str(key)
        self.env["PI_REQUESTY_URL"] = "https://router.invalid/v1"
        (self.agent / "models.json").write_text(
            json.dumps(
                {
                    "providers": {
                        "alucard-requesty": {"baseUrl": "https://old.invalid"},
                        "requesty": {"models": [{"id": "discovered"}]},
                    }
                }
            )
        )
        self.assertEqual(self.invoke().returncode, 0)
        file = self.agent / "models.json"
        providers = json.loads(file.read_text())["providers"]
        self.assertNotIn("alucard-requesty", providers)
        self.assertEqual(providers["requesty"]["apiKey"], "secret-value")
        self.assertEqual(providers["requesty"]["baseUrl"], "https://router.invalid/v1")
        self.assertEqual(providers["requesty"]["models"], [{"id": "discovered"}])
        self.assertEqual(file.stat().st_mode & 0o777, 0o600)

    def test_invalid_settings_are_not_overwritten(self) -> None:
        file = self.agent / "settings.json"
        file.write_text("not json\n")
        self.assertNotEqual(self.invoke().returncode, 0)
        self.assertEqual(file.read_text(), "not json\n")
        self.assertFalse(list(self.agent.glob("settings.json.*")))


if __name__ == "__main__":
    unittest.main()
