import shutil
import json
import hashlib
import importlib.util
from unittest import mock
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace
from argparse import Namespace
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class ContentOperations(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        shutil.copytree(ROOT / 'scripts', self.root / 'scripts')
        shutil.copytree(ROOT / 'templates', self.root / 'templates')
        shutil.copytree(ROOT / 'wiki', self.root / 'wiki')
        self.input = self.root / 'input.md'
        self.input.write_text('---\nid: note\ntype: resource\nstatus: active\ncreated: 2026-11-17\nupdated: 2026-11-17\nauthor: human\nsources: []\n---\n\n# Nota\n', encoding='utf-8')

    def tearDown(self): self.tmp.cleanup()

    def run_cli(self, *args, ok=True):
        result = subprocess.run([sys.executable, str(self.root / 'scripts/content.py'), *args], capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, ok, result.stderr)
        return result




    def test_symlink_and_protected_files_rejected(self):
        (self.root / 'wiki/30_resources/external').symlink_to(self.root, target_is_directory=True)
        self.run_cli('create', '--path', '30_resources/external/escape.md', '--input', str(self.input), ok=False)
        self.run_cli('update', '--path', '_maps/INDEX.md', '--input', str(self.input), ok=False)

    def test_windows_reparse_points_are_detected(self):
        spec = importlib.util.spec_from_file_location('content_reparse', self.root / 'scripts/content.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        path = self.root / 'wiki/30_resources/junction'
        with mock.patch.object(module.Path, 'lstat', return_value=SimpleNamespace(st_mode=0, st_file_attributes=0x400)):
            self.assertTrue(module.is_redirect(path))


    def test_transaction_rolls_back_on_failure(self):
        spec = importlib.util.spec_from_file_location('content_ops', self.root / 'scripts/content.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        first = self.root / 'first.md'
        second = self.root / 'second.md'
        first.write_bytes(b'original')
        with mock.patch.object(module.os, 'link', side_effect=OSError('simulated failure')):
            with self.assertRaises(module.OperationError):
                module.publish({first: b'changed', second: b'new'})
        self.assertEqual(first.read_bytes(), b'original')
        self.assertFalse(second.exists())

    def test_invalid_record_metadata_is_rejected(self):
        self.input.write_text('---\nid: wrong\n---\n# Invalid\n')
        self.run_cli('create', '--path', '20_domains/project-context/records/2026-11-17--bad.md', '--input', str(self.input), ok=False)
        self.assertFalse((self.root / 'wiki/20_domains/project-context/records/2026-11-17--bad.md').exists())

    def test_content_writes_are_logged_and_require_log(self):
        log = self.root / 'wiki/_indexes/action-log.md'
        before = log.read_bytes()
        self.run_cli('create', '--path', '30_resources/sample.md', '--input', str(self.input))
        self.run_cli('update', '--path', '30_resources/sample.md', '--input', str(self.input))
        entries = log.read_bytes()[len(before):].decode('utf-8')
        self.assertIn(' | create | "30_resources/sample.md" | ', entries)
        self.assertIn(' | update | "30_resources/sample.md" | ', entries)
        log.unlink()
        self.run_cli('create', '--path', '30_resources/other.md', '--input', str(self.input), ok=False)
        self.assertFalse((self.root / 'wiki/30_resources/other.md').exists())

    def test_nested_domain_records_cannot_bypass_record_contract(self):
        folder = self.root / 'wiki/20_domains/project-context/records/nested'
        folder.mkdir()
        index = self.root / 'wiki/20_domains/project-context/INDEX.md'
        log = self.root / 'wiki/_indexes/action-log.md'
        index_before, log_before = index.read_bytes(), log.read_bytes()
        path = '20_domains/project-context/records/nested/note.md'
        self.run_cli('create', '--path', path, '--input', str(self.input), ok=False)
        self.assertFalse((self.root / 'wiki' / path).exists())
        self.assertEqual(index.read_bytes(), index_before)
        self.assertEqual(log.read_bytes(), log_before)

    def test_record_index_uses_stable_id_for_arbitrary_headings(self):
        headings = ('Decisión sobre [API](guia.md)', 'Imagen ![logo](logo.png)',
                    'Corchetes [uno] y \\ barra', '`código` <span>texto</span>',
                    'Título con á y 日本語', 'Título ordinario', None)
        domain = self.root / 'wiki/20_domains/project-context'
        shutil.copyfile(self.root / 'templates/wiki-layout/domain-INDEX.md', domain / 'INDEX.md')
        log = self.root / 'wiki/_indexes/action-log.md'
        for number, heading in enumerate(headings):
            with self.subTest(heading=heading):
                record_id = f'2026-11-17--indice-{number}'
                path = f'20_domains/project-context/records/{record_id}.md'
                body = '' if heading is None else '# ' + heading + '\n'
                content = (f'---\nid: {record_id}\ntype: decision\nstatus: active\n'
                           'created: 2026-11-17\nupdated: 2026-11-17\nscope: project\n'
                           'author: human\nsources: []\nrelated: []\nsupersedes: null\n'
                           'superseded_by: null\n---\n' + body)
                self.input.write_text(content, encoding='utf-8')
                self.run_cli('create', '--path', path, '--input', str(self.input))
                self.assertEqual((self.root / 'wiki' / path).read_text(encoding='utf-8'), content)
                index = (domain / 'INDEX.md').read_text(encoding='utf-8')
                active = index.split('## Activos', 1)[1].split('## Retirados', 1)[0]
                self.assertEqual(active.count(f'- [{record_id}](records/{record_id}.md)'), 1)
                self.assertIn(f' | create | "{path}" | ', log.read_text(encoding='utf-8'))

    def test_cli_log_failure_rolls_back_record_and_index(self):
        spec = importlib.util.spec_from_file_location('content_cli_log', self.root / 'scripts/content.py')
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        path = '20_domains/project-context/records/2026-11-17--test.md'
        self.input.write_text('---\nid: 2026-11-17--test\ntype: decision\nstatus: active\ncreated: 2026-11-17\nupdated: 2026-11-17\nscope: project\nauthor: human\nsources: []\nrelated: []\nsupersedes: null\nsuperseded_by: null\n---\n# Test\n')
        index = self.root / 'wiki/20_domains/project-context/INDEX.md'
        log = self.root / 'wiki/_indexes/action-log.md'
        index_before, log_before = index.read_bytes(), log.read_bytes()
        real_replace = module.os.replace
        def replace(source, destination):
            if Path(destination).resolve() == log.resolve(): raise OSError('simulated log failure')
            return real_replace(source, destination)
        args = Namespace(operation='create', path=path, input=str(self.input), type=None, destination=None)
        with mock.patch.object(module.os, 'replace', side_effect=replace):
            with self.assertRaises(module.OperationError): module.run_locked(args)
        self.assertFalse((self.root / 'wiki' / path).exists())
        self.assertEqual(index.read_bytes(), index_before)
        self.assertEqual(log.read_bytes(), log_before)
        self.assertFalse((self.root / 'wiki/.local-mem.lock').exists())

    def test_template_output_and_unfinished_template(self):
        for kind in ('decision', 'convention', 'lesson', 'project-context', 'area', 'daily', 'pending-decision', 'export', 'resource', 'map', 'archive'):
            with self.subTest(kind=kind):
                self.assertTrue(self.run_cli('template', '--type', kind).stdout)
        self.input.write_text(self.run_cli('template', '--type', 'daily').stdout)
        self.run_cli('create', '--path', '50_daily/note.md', '--input', str(self.input), ok=False)
        self.assertFalse((self.root / 'wiki/50_daily/note.md').exists())



    def test_log_failure_rolls_back_content_and_index(self):
        spec = importlib.util.spec_from_file_location('content_log_test', self.root / 'scripts/content.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        content = self.root / 'content.md'
        index = self.root / 'index.md'
        log = self.root / 'action-log.md'
        for path in (content, index, log): path.write_bytes(b'original')
        real_replace = module.os.replace
        def replace(source, destination):
            if Path(destination) == log: raise OSError('log failure')
            return real_replace(source, destination)
        with mock.patch.object(module.os, 'replace', side_effect=replace):
            with self.assertRaises(module.OperationError):
                module.publish({content: b'changed', index: b'changed', log: b'changed'})
        for path in (content, index, log): self.assertEqual(path.read_bytes(), b'original')

    def test_all_markdown_templates_have_metadata(self):
        for directory in (self.root / 'templates/records', self.root / 'templates/wiki-layout', self.root / 'wiki/_templates'):
            for path in directory.glob('*.md'):
                with self.subTest(path=str(path)):
                    self.assertTrue(path.read_text(encoding='utf-8').startswith('---\n'), str(path))

    def test_update_preserves_multiline_sources(self):
        path = '30_resources/multiline.md'
        value = '---\nid: note\ntype: resource\nstatus: active\ncreated: 2026-11-17\nupdated: 2026-11-17\nauthor: human\nsources:\n  - reference.md\n---\n\n# Note\n'
        self.input.write_text(value)
        self.run_cli('create', '--path', path, '--input', str(self.input))
        self.run_cli('update', '--path', path, '--input', str(self.input))

    def test_record_update_cannot_change_lifecycle_status(self):
        path = '20_domains/project-context/records/2026-11-22--wiki-storage-location.md'
        record = self.root / 'wiki' / path
        index = self.root / 'wiki/20_domains/project-context/INDEX.md'
        log = self.root / 'wiki/_indexes/action-log.md'
        original = record.read_text(encoding='utf-8')
        self.assertIn('status: active', original)
        for old, new in (('active', 'retired'), ('retired', 'active')):
            with self.subTest(old=old, new=new):
                before = original.replace('status: active', 'status: ' + old, 1)
                record.write_text(before, encoding='utf-8')
                index_before, log_before = index.read_bytes(), log.read_bytes()
                self.input.write_text(before.replace('status: ' + old, 'status: ' + new, 1), encoding='utf-8')
                result = self.run_cli('update', '--path', path, '--input', str(self.input), ok=False)
                self.assertIn('status', result.stderr)
                self.assertEqual(record.read_text(encoding='utf-8'), before)
                self.assertEqual(index.read_bytes(), index_before)
                self.assertEqual(log.read_bytes(), log_before)
                self.assertFalse((self.root / 'wiki/.local-mem.lock').exists())
        record.write_text(original, encoding='utf-8')
        self.input.write_text(original + '\nEdición ordinaria.\n', encoding='utf-8')
        self.run_cli('update', '--path', path, '--input', str(self.input))
        self.assertEqual(record.read_text(encoding='utf-8'), self.input.read_text(encoding='utf-8'))
        self.assertEqual(index.read_bytes(), index_before)

    def test_read_supports_index_and_domain_metadata(self):
        self.assertIn('Índices', self.run_cli('read', '--path', '_indexes/INDEX.md').stdout)
        self.assertIn('project-context', self.run_cli('read', '--path', '20_domains/project-context/domain.yml').stdout)
        self.run_cli('read', '--path', '../outside', ok=False)

    def test_malformed_front_matter_rejected(self):
        self.input.write_text('---\nid: note\ntype: resource\nstatus: active\ncreated: 2026-11-17\nupdated: 2026-11-17\nauthor: human\nsources: []\n  invalid indentation\n---\n# Note\n')
        self.run_cli('create', '--path', '30_resources/bad.md', '--input', str(self.input), ok=False)



    def test_concurrent_destination_and_existing_conflict(self):
        spec = importlib.util.spec_from_file_location('content_conflict', self.root / 'scripts/content.py')
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        dest = self.root / 'new.md'
        expected = {dest: None}
        dest.write_bytes(b'concurrent')
        with self.assertRaises(module.OperationError): module.publish({dest: b'ours'}, expected)
        self.assertEqual(dest.read_bytes(), b'concurrent')
        existing = self.root / 'existing.md'; existing.write_bytes(b'old')
        expected = {existing: (b'old', existing.stat().st_mode & 0o7777)}
        existing.write_bytes(b'concurrent')
        with self.assertRaises(module.OperationError): module.publish({existing: b'ours'}, expected)
        self.assertEqual(existing.read_bytes(), b'concurrent')



    def test_publication_cleanup_failure_rolls_back_linked_destination(self):
        spec = importlib.util.spec_from_file_location('content_cleanup', self.root / 'scripts/content.py')
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        dest = self.root / 'new.md'
        real_unlink = module.os.unlink
        failed = False
        def unlink(path, *args, **kwargs):
            nonlocal failed
            if Path(path).name.startswith('.content-') and not failed:
                failed = True
                raise OSError('temporary cleanup failure')
            return real_unlink(path, *args, **kwargs)
        with mock.patch.object(module.os, 'unlink', side_effect=unlink):
            with self.assertRaises(module.OperationError): module.publish({dest: b'new'}, {dest: None})
        self.assertTrue(failed)
        self.assertFalse(dest.exists())
        self.assertFalse(module.ROLLBACK_FAILED)




    def test_legacy_templates_are_augmented_without_modification(self):
        template = self.root / 'wiki/_templates/daily.md'
        original = '# YYYY-MM-DD\n\n## Mis notas personalizadas\n'
        template.write_text(original)
        output = self.run_cli('template', '--type', 'daily').stdout
        self.assertIn('type: daily', output)
        self.assertIn(original, output)
        self.assertEqual(template.read_text(), original)
        self.input.write_text(output.replace('YYYY-MM-DD', '2026-11-17').replace('DOCUMENT_ID', '2026-11-17').replace('AUTHOR', 'human'))
        self.run_cli('create', '--path', '50_daily/2026-11-17.md', '--input', str(self.input))
        self.assertIn('Mis notas personalizadas', (self.root / 'wiki/50_daily/2026-11-17.md').read_text())

    def test_legacy_pending_template_gains_missing_metadata(self):
        template = self.root / 'wiki/_templates/pending-decision.md'
        original = '---\nid: old\nstatus: pending\nsource: custom\nproposed_domain: null\ncreated: 2026-11-17\n---\n# Personalizado\n'
        template.write_text(original)
        output = self.run_cli('template', '--type', 'pending-decision').stdout
        self.assertIn('source: custom', output)
        self.assertIn('type: pending-decision', output)
        self.assertEqual(template.read_text(), original)




    def test_invalid_frontmatter_values_are_rejected(self):
        base = '---\nid: note\ntype: resource\nstatus: active\ncreated: 2026-11-17\nupdated: 2026-11-17\nauthor: VALUE\nsources: []\n---\n# Note\n'
        for value in ('[malformed', '"unterminated', '{bad', 'bad: value'):
            with self.subTest(value=value):
                self.input.write_text(base.replace('VALUE', value))
                self.run_cli('create', '--path', '30_resources/a.md', '--input', str(self.input), ok=False)
                self.assertFalse((self.root / 'wiki/30_resources/a.md').exists())





    def test_create_update_across_content_sections(self):
        for section in ('00_inbox', '10_areas', '30_resources', '40_archive', '50_daily', '60_exports', '_maps', '20_domains/project-context/resources'):
            with self.subTest(section=section):
                path = section + ('/2026-11-17.md' if section == '50_daily' else '/sample.md')
                self.run_cli('create', '--path', path, '--input', str(self.input))
                self.assertIn('Nota', self.run_cli('read', '--path', path).stdout)
                self.run_cli('update', '--path', path, '--input', str(self.input))

    def test_move_and_retire_require_manual_review_for_all_markdown_forms(self):
        source = self.root / 'wiki/30_resources/a.md'; source.write_text('# A\n')
        ref = source.parent / 'ref.md'
        variants = ('[link](a.md)', '[link](\na.md)', r'\[literal](a.md)', '`code\n[link](a.md)`', '[label](a(1).md)', '    [list](a.md)', '<a href="a.md">link</a>')
        for value in variants:
            with self.subTest(value=value):
                ref.write_text(value)
                before = {p.relative_to(self.root / 'wiki'): p.read_bytes() for p in (self.root / 'wiki').rglob('*') if p.is_file()}
                self.run_cli('move', '--path', '30_resources/a.md', '--destination', '30_resources/b.md', ok=False)
                self.run_cli('retire', '--path', '30_resources/a.md', ok=False)
                after = {p.relative_to(self.root / 'wiki'): p.read_bytes() for p in (self.root / 'wiki').rglob('*') if p.is_file()}
                self.assertEqual(after, before)

    def test_manual_plan_inventories_entire_wiki_without_writing(self):
        source = self.root / 'wiki/30_resources/a.md'; source.write_text('# A\n')
        note = source.parent / 'ref.md'; note.write_text('[ref](\na.md)\n')
        before = {p.relative_to(self.root / 'wiki'): p.read_bytes() for p in (self.root / 'wiki').rglob('*') if p.is_file()}
        result = json.loads(self.run_cli('plan-move', '--path', '30_resources/a.md', '--destination', '30_resources/b.md').stdout)
        self.assertEqual(result['source'], '30_resources/a.md')
        self.assertEqual(result['destination'], '30_resources/b.md')
        self.assertTrue(result['review_required'])
        docs = {x['path']: x['sha256'] for x in result['documents']}
        self.assertEqual(set(docs), {p.as_posix() for p in before})
        self.assertEqual(docs['30_resources/ref.md'], hashlib.sha256(note.read_bytes()).hexdigest())
        retirement = json.loads(self.run_cli('plan-retire', '--path', '30_resources/a.md').stdout)
        self.assertEqual(retirement['destination'], '40_archive/30_resources/a.md')
        self.assertEqual(before, {p.relative_to(self.root / 'wiki'): p.read_bytes() for p in (self.root / 'wiki').rglob('*') if p.is_file()})

    def test_manual_plan_rejects_existing_destination_and_symlink(self):
        source = self.root / 'wiki/30_resources/a.md'; source.write_text('# A\n')
        source.with_name('b.md').write_text('# B\n')
        self.run_cli('plan-move', '--path', '30_resources/a.md', '--destination', '30_resources/b.md', ok=False)
        (source.parent / 'external').symlink_to(self.root, target_is_directory=True)
        self.run_cli('plan-retire', '--path', '30_resources/a.md', ok=False)

    def test_manual_plan_does_not_ignore_inaccessible_directories(self):
        spec = importlib.util.spec_from_file_location('content_plan_walk', self.root / 'scripts/content.py')
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        source = module.WIKI / '30_resources/a.md'; source.write_text('# A\n')
        restricted = source.parent / 'restricted'; restricted.mkdir()
        original_scandir = module.os.scandir
        def scandir(path):
            if Path(path).resolve() == restricted.resolve(): raise PermissionError('simulated inaccessible directory')
            return original_scandir(path)
        with mock.patch.object(module.os, 'scandir', side_effect=scandir):
            with self.assertRaises(PermissionError): module.manual_plan('retire', source, module.WIKI / '40_archive/30_resources/a.md')

    def test_legacy_pending_update_preserves_metadata(self):
        path = '00_inbox/decisions-pending/legacy.md'
        original = '---\nid: legacy\nstatus: pending\nsource: records/legacy.md\nproposed_domain: null\ncreated: 2026-11-17\n---\n\n# Pending\n'
        document = self.root / 'wiki' / path; document.parent.mkdir(parents=True, exist_ok=True); document.write_text(original)
        self.input.write_text(original + 'New content\n')
        self.run_cli('update', '--path', path, '--input', str(self.input))
        self.assertEqual(document.read_text(), original + 'New content\n')

    def test_partial_frontmatter_update_preserves_metadata(self):
        path = '30_resources/legacy.md'; document = self.root / 'wiki' / path
        document.write_text('---\ntitle: Existing\n---\n# Original\n')
        self.input.write_text('---\ntitle: Existing\n---\n# Updated\n')
        self.run_cli('update', '--path', path, '--input', str(self.input))
        self.assertEqual(document.read_text(), self.input.read_text())

    def test_manual_plan_can_be_compared_under_lock(self):
        source = self.root / 'wiki/30_resources/a.md'; source.write_text('# A\n')
        args = ('plan-retire', '--path', '30_resources/a.md')
        first = json.loads(self.run_cli(*args).stdout)
        lock = self.root / 'wiki/.local-mem.lock'; lock.write_text('manual operator')
        locked = json.loads(self.run_cli(*args).stdout)
        self.assertEqual(first, locked)
        source.write_text('# Changed\n')
        changed = json.loads(self.run_cli(*args).stdout)
        self.assertNotEqual(first['documents'], changed['documents'])
        self.assertEqual(lock.read_text(), 'manual operator')

    def test_manual_plan_rejects_scope_and_record_move(self):
        self.run_cli('plan-retire', '--path', '../outside.md', ok=False)
        path = '20_domains/project-context/records/2026-11-16--single-installation-mode.md'
        self.run_cli('plan-move', '--path', path, '--destination', '20_domains/project-context/records/new.md', ok=False)
        self.run_cli('plan-move', '--path', '30_resources/nonexistent.md', '--destination', '30_resources/b.md', ok=False)

    def test_wikilink_plan_apply_converts_supported_links_and_logs_changes(self):
        target = self.root / 'wiki/30_resources/nota con espacio.md'
        target.write_text('# Sección con ñ\n')
        source = self.root / 'wiki/30_resources/origen.md'
        source.write_text(
            '---\nid: origen\ntype: resource\nstatus: active\ncreated: 2026-11-17\nupdated: 2026-11-17\n'
            'author: human\nsources:\n  - \"[[nota con espacio]]\"\nrelated: \"[[nota con espacio#Sección con ñ|Sección]]\"\n'
            'supersedes: [\"[[nota con espacio|Previa]]\"]\ncustom: \"[[nota con espacio]]\"\n---\n# Example\n[[nota con espacio]]\n[[nota con espacio|Etiqueta]]\n'
            '[[nota con espacio#Sección con ñ]]\n[[#Example]]\n`[[nota con espacio]]`\n'
            '```md\n[[nota con espacio]]\n```\n%% [[nota con espacio]] %%\n'
            '<!-- [[nota con espacio]] -->\n![[nota con espacio]]\n[[nota con espacio#^bloque]]\n[[ausente]]\n[[|empty-target]]\n'
            '`%%` %% [[nota con espacio]] %% [[nota con espacio]]\n'
            '`<!--` <!-- [[nota con espacio]] --> [[nota con espacio]]\n',
            encoding='utf-8')
        agents = self.root / 'wiki/AGENTS.md'
        agents.write_text(agents.read_text(encoding='utf-8') + '\n[[nota con espacio|instrucción]]\n', encoding='utf-8')
        index = self.root / 'wiki/_indexes/INDEX.md'
        index.write_text(index.read_text(encoding='utf-8') + '\n[[nota con espacio]]\n', encoding='utf-8')
        obsidian = self.root / 'wiki/.obsidian'
        obsidian.mkdir()
        (obsidian / 'sample.md').write_text('[[nota con espacio]]\n', encoding='utf-8')

        log = self.root / 'wiki/_indexes/action-log.md'
        before_log = log.read_bytes()
        result = self.run_cli('plan-links')
        plan = json.loads(result.stdout)
        plan_path = self.root / 'plan.json'
        plan_path.write_text(result.stdout, encoding='utf-8')

        self.assertIn('nota%20con%20espacio.md#Secci%C3%B3n%20con%20%C3%B1', plan['diff'])
        self.assertNotIn('.obsidian/sample.md', [item['path'] for item in plan['snapshot']])
        self.assertEqual(log.read_bytes(), before_log)
        self.assertIn('[[nota con espacio]]', source.read_text(encoding='utf-8'))
        self.assertGreaterEqual(len(plan['changes']), 3)
        reasons = {item['reason'] for item in plan['unsupported']}
        self.assertIn('embed no soportado', reasons)
        self.assertIn('referencia a bloque no soportada', reasons)
        self.assertTrue(any(item['link'] == '![[nota con espacio]]' for item in plan['unsupported']))
        self.assertTrue(any(item['reason'] == 'campo YAML fuera del alcance' for item in plan['unsupported']))
        self.assertTrue(any(item['reason'] == 'destino vacío' for item in plan['unsupported']))
        self.assertTrue(any(item['reason'] == 'destino inexistente o alias de nota' for item in plan['unresolved']))

        applied = json.loads(self.run_cli('apply-links', '--plan', str(plan_path)).stdout)
        self.assertEqual(applied['converted'], sum(len(item['replacements']) for item in plan['changes']))
        self.assertIn('[Etiqueta](nota%20con%20espacio.md)', source.read_text(encoding='utf-8'))
        self.assertIn('[Sección](nota%20con%20espacio.md#Secci%C3%B3n%20con%20%C3%B1)', source.read_text(encoding='utf-8'))
        self.assertIn('supersedes: [\"[Previa](nota%20con%20espacio.md)\"]', source.read_text(encoding='utf-8'))
        self.assertIn('[Example](#Example)', source.read_text(encoding='utf-8'))
        self.assertIn('`[[nota con espacio]]`', source.read_text(encoding='utf-8'))
        self.assertIn('```md\n[[nota con espacio]]\n```', source.read_text(encoding='utf-8'))
        self.assertIn('%% [[nota con espacio]] %%', source.read_text(encoding='utf-8'))
        self.assertIn('<!-- [[nota con espacio]] -->', source.read_text(encoding='utf-8'))
        self.assertIn('`%%` %% [[nota con espacio]] %% [nota con espacio](nota%20con%20espacio.md)', source.read_text(encoding='utf-8'))
        self.assertIn('`<!--` <!-- [[nota con espacio]] --> [nota con espacio](nota%20con%20espacio.md)', source.read_text(encoding='utf-8'))
        self.assertIn('![[nota con espacio]]', source.read_text(encoding='utf-8'))
        self.assertIn('[[nota con espacio#^bloque]]', source.read_text(encoding='utf-8'))
        self.assertIn(' | curate-links | \"30_resources/origen.md\" | ', log.read_text(encoding='utf-8'))
        self.assertIn(' | curate-links | \"AGENTS.md\" | ', log.read_text(encoding='utf-8'))
        self.assertFalse((self.root / 'wiki/.local-mem.lock').exists())
        self.assertEqual(json.loads(self.run_cli('plan-links').stdout)['changes'], [])

    def test_wikilink_plan_reports_ambiguity_and_stale_apply_does_not_write(self):
        source = self.root / 'wiki/30_resources/source.md'
        source.write_text('[[shared]]\n[[30_resources/shared]]\n[[one#Missing]]\n[[one#Repeated]]\n',
                          encoding='utf-8')
        (self.root / 'wiki/30_resources/shared.md').write_text('# Shared\n')
        (self.root / 'wiki/40_archive/shared.md').write_text('# Other shared\n')
        (self.root / 'wiki/30_resources/one.md').write_text('# Repeated\n# Repeated\n')
        result = self.run_cli('plan-links')
        plan = json.loads(result.stdout)
        self.assertTrue(any(item['reason'] == 'nombre de nota ambiguo' for item in plan['unresolved']))
        self.assertTrue(any(item['reason'] == 'encabezado inexistente' for item in plan['unresolved']))
        self.assertTrue(any(item['reason'] == 'encabezado repetido' for item in plan['unresolved']))
        self.assertEqual(len(plan['changes']), 1)
        plan_path = self.root / 'plan.json'
        plan_path.write_text(result.stdout, encoding='utf-8')
        source.write_text(source.read_text(encoding='utf-8') + 'changed after review\n', encoding='utf-8')
        log_before = (self.root / 'wiki/_indexes/action-log.md').read_bytes()
        self.run_cli('apply-links', '--plan', str(plan_path), ok=False)
        self.assertIn('[[30_resources/shared]]', source.read_text(encoding='utf-8'))
        self.assertEqual((self.root / 'wiki/_indexes/action-log.md').read_bytes(), log_before)
        self.assertFalse((self.root / 'wiki/.local-mem.lock').exists())

    def test_wikilink_plan_scope_lock_and_symlink_guards(self):
        source = self.root / 'wiki/30_resources/source.md'
        source.write_text('[[target]]\n')
        (self.root / 'wiki/30_resources/target.md').write_text('# Target\n')
        other = self.root / 'wiki/40_archive/other.md'
        other.write_text('[[target]]\n')
        result = json.loads(self.run_cli('plan-links', '--path', '30_resources/source.md').stdout)
        self.assertEqual([item['path'] for item in result['changes']], ['30_resources/source.md'])
        lock = self.root / 'wiki/.local-mem.lock'
        lock.write_text('manual operation\n')
        self.run_cli('plan-links', ok=False)
        self.assertEqual(lock.read_text(), 'manual operation\n')
        lock.unlink()
        link = self.root / 'wiki/60_exports/external.md'
        link.symlink_to(source)
        self.run_cli('plan-links', ok=False)
        link.unlink()

    def test_wikilink_apply_rolls_back_if_action_log_publication_fails(self):
        source = self.root / 'wiki/30_resources/source.md'
        source.write_text('[[target]]\n')
        (self.root / 'wiki/30_resources/target.md').write_text('# Target\n')
        plan_path = self.root / 'plan.json'
        plan_path.write_text(self.run_cli('plan-links').stdout, encoding='utf-8')
        log = self.root / 'wiki/_indexes/action-log.md'
        before_source, before_log = source.read_bytes(), log.read_bytes()

        spec = importlib.util.spec_from_file_location('content_links_rollback', self.root / 'scripts/content.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        args = Namespace(operation='apply-links', plan=str(plan_path), path=None, type=None, input=None, destination=None)
        real_replace = module.os.replace
        def fail_log_replace(origin, destination):
            if Path(destination).name == 'action-log.md': raise OSError('simulated action log failure')
            return real_replace(origin, destination)
        with mock.patch.object(module.os, 'replace', side_effect=fail_log_replace):
            with self.assertRaises(module.OperationError): module.run_locked(args)
        self.assertEqual(source.read_bytes(), before_source)
        self.assertEqual(log.read_bytes(), before_log)
        self.assertFalse((self.root / 'wiki/.local-mem.lock').exists())

    def test_new_names_are_validated_without_rejecting_legacy_reads(self):
        for name in ('bad name.md', 'bad_name.md', 'Bad.md', 'a--b.md', 'aux.md', 'com1.md'):
            with self.subTest(name=name):
                self.run_cli('create', '--path', '30_resources/' + name, '--input', str(self.input), ok=False)
        self.run_cli('create', '--path', '30_resources/guia-2026.md', '--input', str(self.input))
        for name in ('2026-02-30.md', '2026-2-01.md', 'sample.md'):
            self.run_cli('create', '--path', '50_daily/' + name, '--input', str(self.input), ok=False)
        self.run_cli('create', '--path', '50_daily/2024-02-29.md', '--input', str(self.input))
        self.run_cli('create', '--path', '20_domains/project-context/records/2026-02-30--decision.md', '--input', str(self.input), ok=False)
        legacy = self.root / 'wiki/30_resources/Nombre anterior.md'
        legacy.write_text('# Existente\n')
        self.assertIn('Existente', self.run_cli('read', '--path', '30_resources/Nombre anterior.md').stdout)
        self.run_cli('plan-retire', '--path', '30_resources/Nombre anterior.md')
        self.run_cli('plan-move', '--path', '30_resources/Nombre anterior.md', '--destination', '30_resources/Nombre nuevo.md', ok=False)
        self.run_cli('plan-move', '--path', '30_resources/Nombre anterior.md', '--destination', '30_resources/nombre-nuevo.md')

if __name__ == '__main__': unittest.main()
