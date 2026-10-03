"""Exercise the updater against local Git sources and a verified wheel fixture."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

SCRIPT = Path(sys.argv.pop(1)).resolve()
BASH = shutil.which("bash")
assert BASH is not None, "Tests require Bash"


class UpdateSkillsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "config"
        self.destination = self.repo / "ai/skills/shared/demo"
        self.destination.mkdir(parents=True)
        (self.destination / "SKILL.md").write_text("old\n")
        (self.destination / "obsolete").write_text("remove me\n")
        self.env = dict(os.environ, SKILLS_REPO=str(self.repo))
        self.env.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
        self.remote = self.root / "remote"
        (self.remote / "demo").mkdir(parents=True)
        (self.remote / "demo/SKILL.md").write_text("new\n")
        for args in (
            ["init", "--quiet", str(self.remote)],
            ["-C", str(self.remote), "add", "."],
            [
                "-C",
                str(self.remote),
                "-c",
                "user.name=Test",
                "-c",
                "user.email=test@example.invalid",
                "commit",
                "--quiet",
                "-m",
                "fixture",
            ],
            ["-C", str(self.remote), "tag", "v1.2.3"],
        ):
            subprocess.run(
                ["git", *args],
                check=True,
                env=self.env,
                capture_output=True,
                timeout=30,
            )
        self.sources = {
            "demo": {"type": "git", "repo": self.remote.as_uri(), "path": "demo"}
        }
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env["PATH"] = f"{self.bin}{os.pathsep}{self.env['PATH']}"

    def invoke(self, mode: str, *names: str) -> subprocess.CompletedProcess[str]:
        (self.repo / "ai/skills/sources.json").write_text(
            json.dumps({"skills": self.sources})
        )
        return subprocess.run(
            ["bash", str(SCRIPT), mode, *names],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )

    def test_check_is_read_only(self) -> None:
        result = self.invoke("check")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("differs", result.stdout)
        self.assertEqual((self.destination / "SKILL.md").read_text(), "old\n")
        self.assertTrue((self.destination / "obsolete").exists())

    def test_apply_replaces_only_declared_skill(self) -> None:
        authored = self.repo / "ai/skills/shared/authored"
        authored.mkdir()
        (authored / "SKILL.md").write_text("local\n")
        result = self.invoke("apply", "demo")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.destination / "SKILL.md").read_text(), "new\n")
        self.assertFalse((self.destination / "obsolete").exists())
        self.assertEqual((authored / "SKILL.md").read_text(), "local\n")
        self.assertIn("current", self.invoke("check").stdout)
        self.assertNotEqual(self.invoke("apply", "authored").returncode, 0)

    def test_failed_fetch_leaves_all_skills_untouched(self) -> None:
        self.sources["z-broken"] = {
            "type": "git",
            "repo": (self.root / "missing").as_uri(),
            "path": "demo",
        }
        self.assertNotEqual(self.invoke("apply").returncode, 0)
        self.assertEqual((self.destination / "SKILL.md").read_text(), "old\n")
        self.assertFalse((self.repo / "ai/skills/shared/z-broken").exists())

    def test_package_version_selects_tag_without_editing_pin(self) -> None:
        self.sources["demo"]["packageAttribute"] = "linear-cli"
        nix = self.bin / "nix"
        nix.write_text(
            f'#!{BASH}\ncase "$*" in\n*currentSystem*) printf test-system;;\n*"#packages.test-system.linear-cli.version") printf 1.2.3;;\n*) exit 2;;\nesac\n'
        )
        nix.chmod(0o755)
        pin = self.repo / "package.nix"
        pin.write_text('version = "1.2.3";\n')
        result = self.invoke("apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(pin.read_text(), 'version = "1.2.3";\n')

    def test_wheel_checksum_is_required(self) -> None:
        wheel = self.root / "fixture.whl"
        with zipfile.ZipFile(wheel, "w") as archive:
            archive.writestr("zotero_mcp/skills/demo/SKILL.md", "wheel\n")
        digest = hashlib.sha256(wheel.read_bytes()).hexdigest()
        metadata = self.root / "metadata.json"
        self.sources = {
            "demo": {
                "type": "pypi",
                "package": "fixture",
                "version": "1.2.3",
                "path": "zotero_mcp/skills/demo",
            }
        }
        curl = self.bin / "curl"
        curl.write_text(
            f'#!{BASH}\nwhile [ "$#" -gt 0 ]; do\n if [ "$1" = --output ]; then cp "{wheel}" "$2"; exit; fi\n shift\ndone\ncat "{metadata}"\n'
        )
        curl.chmod(0o755)
        for checksum, success in (("0" * 64, False), (digest, True)):
            metadata.write_text(
                json.dumps(
                    {
                        "urls": [
                            {
                                "packagetype": "bdist_wheel",
                                "url": "https://fixture.invalid/wheel",
                                "digests": {"sha256": checksum},
                            }
                        ]
                    }
                )
            )
            result = self.invoke("apply")
            self.assertEqual(result.returncode == 0, success, result.stderr)
            expected = "wheel\n" if success else "old\n"
            self.assertEqual((self.destination / "SKILL.md").read_text(), expected)


if __name__ == "__main__":
    unittest.main()
