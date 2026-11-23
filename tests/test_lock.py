import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class LockTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        for name in ('scripts', 'templates', 'vault'):
            shutil.copytree(ROOT / name, self.root / name)
        for name in ('SKILL.md', 'VAULT_FORMAT', 'VERSION'):
            shutil.copy(ROOT / name, self.root / name)
        self.input = self.root / 'input.md'
        self.input.write_text('---\nid: example\ntype: resource\nstatus: active\ncreated: 2026-11-17\nupdated: 2026-11-17\nauthor: human\nsources: []\n---\n# Example\n')
        self.lock = self.root / 'vault/.local-mem.lock'

    def tearDown(self): self.tmp.cleanup()

    def cli(self, *args):
        return subprocess.run([sys.executable, str(self.root / 'scripts/content.py'), *args], capture_output=True, text=True)

    def test_busy_lock_blocks_all_writers_and_readers_continue(self):
        self.lock.write_text('operation: existing\n')
        p = self.cli('create', '--path', '30_resources/a.md', '--input', str(self.input))
        self.assertNotEqual(p.returncode, 0); self.assertIn('bloqueada', p.stderr)
        p = subprocess.run(['sh', str(self.root / 'scripts/vault.sh'), 'init-layout'], capture_output=True, text=True)
        self.assertNotEqual(p.returncode, 0); self.assertIn('bloqueada', p.stderr)
        if shutil.which('pwsh'):
            p = subprocess.run(['pwsh', '-NoProfile', '-File', str(self.root / 'scripts/vault.ps1'), 'init-layout'], capture_output=True, text=True)
            self.assertNotEqual(p.returncode, 0); self.assertIn('bloqueada', p.stderr)
        self.assertEqual(self.cli('read', '--path', '_indexes/INDEX.md').returncode, 0)
        self.assertEqual(self.lock.read_text(), 'operation: existing\n')

    def test_python_success_and_validation_failure_release_lock(self):
        p = self.cli('create', '--path', '30_resources/a.md', '--input', str(self.input))
        self.assertEqual(p.returncode, 0, p.stderr); self.assertFalse(self.lock.exists())
        p = self.cli('create', '--path', '30_resources/a.md', '--input', str(self.input))
        self.assertNotEqual(p.returncode, 0); self.assertFalse(self.lock.exists())

    def test_interruption_retains_prepared_plan_and_blocks(self):
        harness = '''import importlib.util, sys
spec=importlib.util.spec_from_file_location("content", sys.argv[1])
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
def pause(*args):
 print("READY", flush=True)
 sys.stdin.readline()
m.publish=pause
sys.argv=[sys.argv[1], "create", "--path", "30_resources/a.md", "--input", sys.argv[2]]
m.run_locked(m.parse_args())
'''
        process = subprocess.Popen([sys.executable, '-u', '-c', harness, str(self.root / 'scripts/content.py'), str(self.input)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            self.assertEqual(process.stdout.readline().strip(), 'READY')
            self.assertIn('30_resources/a.md', self.lock.read_text())
            p = self.cli('create', '--path', '30_resources/b.md', '--input', str(self.input))
            self.assertNotEqual(p.returncode, 0)
            process.kill(); process.wait(timeout=10)
            self.assertTrue(self.lock.exists())
            self.assertNotEqual(self.cli('create', '--path', '30_resources/b.md', '--input', str(self.input)).returncode, 0)
        finally:
            if process.poll() is None: process.kill(); process.wait()
            for stream in (process.stdin, process.stdout, process.stderr): stream.close()

    def test_shell_error_retains_plan(self):
        p = subprocess.run(['sh', str(self.root / 'scripts/vault.sh'), 'create-domain', '--id', 'INVALID'], capture_output=True, text=True)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('create-domain', self.lock.read_text())

    def test_incomplete_rollback_retains_lock(self):
        harness = """import importlib.util, sys
spec=importlib.util.spec_from_file_location('content', sys.argv[1])
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
def fail_publish(*args):
 m.PUBLICATION_STARTED=True
 m.ROLLBACK_FAILED=True
 raise m.OperationError('rollback failure')
m.publish=fail_publish
sys.argv=[sys.argv[1], 'create', '--path', '30_resources/a.md', '--input', sys.argv[2]]
try: m.run_locked(m.parse_args())
except m.OperationError: pass
"""
        result = subprocess.run([sys.executable, '-c', harness, str(self.root / 'scripts/content.py'), str(self.input)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.lock.exists())
        self.assertIn('30_resources/a.md', self.lock.read_text())
        self.assertNotEqual(self.cli('create', '--path', '30_resources/b.md', '--input', str(self.input)).returncode, 0)

    def test_option_before_operation_cannot_bypass_lock(self):
        self.lock.write_text('operation: other\n')
        result = self.cli('--path', '30_resources/a.md', '--input', str(self.input), 'create')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('bloqueada', result.stderr)
        self.assertFalse((self.root / 'vault/30_resources/a.md').exists())
        self.assertEqual(self.lock.read_text(), 'operation: other\n')

    def test_invalid_arguments_do_not_create_lock(self):
        self.assertNotEqual(self.cli('create', '--bad').returncode, 0)
        self.assertFalse(self.lock.exists())
        self.assertEqual(self.cli('create', '--help').returncode, 0)
        self.assertFalse(self.lock.exists())

if __name__ == '__main__': unittest.main()
