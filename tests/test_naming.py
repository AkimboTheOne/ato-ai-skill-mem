import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class DomainNamingTests(unittest.TestCase):
    def test_new_names_and_legacy_diagnostic(self):
        interfaces = [('sh', 'vault.sh')]
        if shutil.which('pwsh'):
            interfaces.append(('pwsh', 'vault.ps1'))
        for runtime, script in interfaces:
            with self.subTest(runtime=runtime), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                for folder in ('scripts', 'templates', 'vault'):
                    shutil.copytree(ROOT / folder, root / folder)
                shutil.copy(ROOT / 'VAULT_FORMAT', root / 'VAULT_FORMAT')
                command = [runtime] + (['-NoProfile', '-File'] if runtime == 'pwsh' else []) + [str(root / 'scripts' / script)]
                option = '-Id' if runtime == 'pwsh' else '--id'
                for value in ('con', 'com1', 'two--parts', 'trailing-', 'x' * 64):
                    result = subprocess.run(command + ['create-domain', option, value], capture_output=True, text=True)
                    self.assertNotEqual(result.returncode, 0, value)
                    (root / 'vault/.local-mem.lock').unlink(missing_ok=True)
                result = subprocess.run(command + ['create-domain', option, 'dominio-1'], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                src = root / 'vault/20_domains/dominio-1'
                legacy = src.with_name('legacy-')
                src.rename(legacy)
                meta = legacy / 'domain.yml'
                meta.write_text(meta.read_text().replace('id: dominio-1', 'id: legacy-'))
                result = subprocess.run(command + ['check'], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)

if __name__ == '__main__': unittest.main()
