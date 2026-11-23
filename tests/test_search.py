import json
import importlib.util
from unittest import mock
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]

class SearchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / 'scripts').mkdir()
        shutil.copy(ROOT / 'scripts/search.py', self.root / 'scripts/search.py')
        self.wiki = self.root / 'wiki'
        domain = self.wiki / '20_domains/engineering'
        domain.mkdir(parents=True)
        (domain / 'INDEX.md').write_text('# Índice\nArquitectura local\n', encoding='utf-8')
        (domain / 'note.md').write_text('---\nstatus: active\ntitle: Memoria\n---\n# Diseño\nLa decisión usa memoria local.\n', encoding='utf-8')
        (domain / 'domain.yml').write_text('id: engineering\nstatus: active\n', encoding='utf-8')

    def tearDown(self): self.temp.cleanup()

    def search(self, *args, code=0):
        result = subprocess.run([sys.executable, str(self.root / 'scripts/search.py'), *args], capture_output=True, text=True)
        self.assertEqual(result.returncode, code, result.stderr)
        return json.loads(result.stdout) if code == 0 else result.stderr

    def test_text_regex_and_language(self):
        self.assertEqual(self.search('decision')['results'][0]['path'], '20_domains/engineering/note.md')
        self.assertEqual(self.search('decisi[oó]n.*memoria', '--mode', 'regex')['results'][0]['matches'][0]['line'], 6)
        self.assertEqual(self.search('memoria decisión', '--mode', 'language')['results'][0]['score'], 2)
        self.assertEqual(self.search('missing')['results'], [])

    def test_scopes_and_domain(self):
        self.assertEqual(self.search('arquitectura', '--scope', 'indexes')['results'][0]['path'], '20_domains/engineering/INDEX.md')
        self.assertEqual(self.search('active', '--scope', 'headers', '--domain', 'engineering')['results'][0]['matches'][0]['line'], 2)
        self.assertEqual(self.search('decisión', '--scope', 'headers')['results'], [])
        self.search('x', '--domain', '../other', code=2)
        self.search('[', '--mode', 'regex', code=2)

    def test_no_mutations_and_symlinks_rejected(self):
        before = {p: p.read_bytes() for p in self.wiki.rglob('*') if p.is_file()}
        self.search('memoria')
        self.assertEqual(before, {p: p.read_bytes() for p in self.wiki.rglob('*') if p.is_file()})
        (self.wiki / 'link').symlink_to(self.root, target_is_directory=True)
        self.search('memoria', code=2)

    def test_windows_reparse_points_are_detected(self):
        spec = importlib.util.spec_from_file_location('search_reparse', self.root / 'scripts/search.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        path = self.wiki / 'junction'
        with mock.patch.object(module.Path, 'lstat', return_value=SimpleNamespace(st_mode=0, st_file_attributes=0x400)):
            self.assertTrue(module.is_redirect(path))

    def test_traversal_error_is_not_silenced(self):
        spec = importlib.util.spec_from_file_location('search_walk', self.root / 'scripts/search.py')
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        restricted = self.wiki / '20_domains/engineering/restricted'; restricted.mkdir()
        original_scandir = module.os.scandir
        def scandir(path):
            if Path(path).resolve() == restricted.resolve(): raise PermissionError('simulated inaccessible directory')
            return original_scandir(path)
        with mock.patch.object(module.os, 'scandir', side_effect=scandir):
            with self.assertRaises(PermissionError): list(module.files('content', None))

if __name__ == '__main__': unittest.main()
