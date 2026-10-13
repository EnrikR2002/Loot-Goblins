import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("memory", Path(__file__).resolve().parents[1] / "scripts/memory.py")
memory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(memory)


def note():
    return {"schema_version": 1, "id": "test-route-lesson", "title": "Test normal routes", "status": "observation", "game": "Example/Game", "date": "2026-10-12", "topics": ["testing"], "rubric_checks": ["CL-08"], "observation": "A blocked route was observed.", "recommendation": "Walk the intended route.", "applies_when": ["An objective has an approach route"], "limits": ["One route on one build"], "evidence": [{"kind": "human-feedback", "url": "https://github.com/Example/Game/blob/" + "a" * 40 + "/docs/report.md", "detail": "One tester encountered a blocked route."}]}


class MemoryTests(unittest.TestCase):
    def setUp(self):
        self.quiet = patch("builtins.print")
        self.quiet.start()
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.snapshot = {"schema_version": 1, "repository": "Example/Notebook", "revision": "b" * 40, "baseline": "# Quality\nCL-08\n", "notes": [note()]}

    def tearDown(self):
        self.quiet.stop()
        self.temp.cleanup()

    def game(self):
        memory.write(self.root / "src/server/Main.lua", "return {}\n")
        memory.write(self.root / "docs/game-guide/identity.md", "# Current game\nA playable route game.\n")
        memory.write(self.root / "docs/AI_CONTEXT.md", "# Current state\nHuman fun is not tested.\n")
        config = {"schema_version": 1, "game_name": "Test Game", "repository": "Example/Game", "knowledge_repository": "Example/Notebook", "reviewed_gameplay_ref": "a" * 40, "chapters": ["docs/game-guide/identity.md"], "appendices": ["docs/AI_CONTEXT.md"], "source_baseline": memory.source_hashes(self.root)}
        memory.write(self.root / "docs/game-guide/manifest.json", memory.json_text(config))
        memory.write(self.root / "docs/team-memory-snapshot.json", memory.json_text(self.snapshot))

    def library(self):
        memory.write(self.root / "library.json", memory.json_text({"schema_version": 1, "repository": "Example/Notebook", "automatic_authors": ["teammate"]}))
        memory.write(self.root / "rubric/BASE.md", self.snapshot["baseline"])
        memory.write(self.root / "lessons/test-route-lesson.json", memory.json_text(note()))
        memory.library_outputs(self.root)

    def test_valid_attributed_note(self):
        memory.validate_note(note())

    def test_unknown_format_is_preserved_and_rejected(self):
        record = note(); record["schema_version"] = 99
        with self.assertRaises(ValueError): memory.validate_note(record)

    def test_no_automatic_universal_claim(self):
        record = note(); record["status"] = "proven-for-every-game"
        with self.assertRaises(ValueError): memory.validate_note(record)

    def test_exact_commit_required(self):
        record = note(); record["evidence"][0]["url"] = "https://github.com/Example/Game/blob/main/docs/report.md"
        with self.assertRaises(ValueError): memory.validate_note(record)

    def test_evidence_method_required(self):
        record = note(); record["evidence"][0]["kind"] = "assumed"
        with self.assertRaises(ValueError): memory.validate_note(record)

    def test_limits_required(self):
        record = note(); record["limits"] = []
        with self.assertRaises(ValueError): memory.validate_note(record)

    def test_filename_escape_rejected(self):
        record = note(); record["id"] = "../../unsafe"
        with self.assertRaises(ValueError): memory.validate_note(record)

    def test_duplicate_id_rejected(self):
        with self.assertRaises(ValueError): memory.validate_library({"schema_version": 1, "repository": "Example/Notebook"}, "CL-08", [note(), note()])

    def test_unknown_check_rejected(self):
        with self.assertRaises(ValueError): memory.validate_library({"schema_version": 1, "repository": "Example/Notebook"}, "CL-01", [note()])

    def test_library_regeneration_is_deterministic(self):
        self.library()
        before = (self.root / "QUALITY_RUBRIC.md").read_bytes()
        memory.library_outputs(self.root)
        self.assertEqual(before, (self.root / "QUALITY_RUBRIC.md").read_bytes())

    def test_stale_generated_rubric_fails(self):
        self.library()
        memory.write(self.root / "QUALITY_RUBRIC.md", "outdated")
        with self.assertRaises(ValueError): memory.library_outputs(self.root, check=True)

    def test_game_guide_contains_full_history_and_rubric(self):
        self.game()
        memory.write(self.root / "docs/reports/2026-10-12-test.md", "# Historical evidence\n" + "Important detail.\n" * 100)
        memory.export(self.root)
        guide = (self.root / "GAME_GUIDE.md").read_text(encoding="utf-8")
        self.assertEqual(guide.count("Important detail."), 100)
        self.assertIn("Test normal routes", guide)
        self.assertIn("Human fun is not tested", guide)
        memory.export(self.root, check=True)

    def test_edited_source_requires_review(self):
        self.game(); memory.export(self.root)
        memory.write(self.root / "src/server/Main.lua", "return {changed = true}\n")
        with self.assertRaisesRegex(ValueError, "source changed"): memory.export(self.root)

    def test_new_source_requires_review(self):
        self.game()
        memory.write(self.root / "src/server/New.lua", "return {}\n")
        with self.assertRaises(ValueError): memory.export(self.root)

    def test_deleted_source_requires_review(self):
        self.game(); (self.root / "src/server/Main.lua").unlink()
        with self.assertRaises(ValueError): memory.export(self.root)

    def test_updated_report_requires_export(self):
        self.game(); memory.export(self.root)
        memory.write(self.root / "docs/reports/2026-10-12-new.md", "# New observation\n")
        with self.assertRaisesRegex(ValueError, "stale"): memory.export(self.root, check=True)

    def test_snapshot_changes_reach_another_game(self):
        self.game(); memory.export(self.root)
        updated = copy.deepcopy(self.snapshot)
        updated["revision"] = "c" * 40
        second = note(); second["id"] = "new-other-game-lesson"; second["title"] = "Another game learned this"; second["game"] = "Example/OtherGame"
        updated["notes"].append(second)
        memory.write(self.root / ".local/team-memory/snapshot.json", memory.json_text(updated))
        memory.export(self.root)
        self.assertIn("Another game learned this", (self.root / "GAME_GUIDE.md").read_text())
        memory.export(self.root, check=True)

    def test_check_is_offline_and_does_not_refresh(self):
        self.game(); memory.export(self.root)
        with patch.object(memory, "api", side_effect=AssertionError("unexpected network")), patch.object(memory, "refresh", side_effect=AssertionError("unexpected refresh")):
            memory.export(self.root, check=True)

    def test_windows_newlines_do_not_make_ci_stale(self):
        self.game(); memory.export(self.root)
        source = self.root / "src/server/Main.lua"
        source.write_bytes(b"return {}\r\n")
        memory.export(self.root, check=True)

    def test_document_windows_newlines_do_not_make_ci_stale(self):
        self.game(); memory.export(self.root)
        chapter = self.root / "docs/game-guide/identity.md"
        chapter.write_bytes(chapter.read_bytes().replace(b"\n", b"\r\n"))
        memory.export(self.root, check=True)

    def test_relative_path_cannot_escape_game(self):
        with self.assertRaises(ValueError): memory.safe_path(self.root, "../outside.md")

    def test_initialization_cannot_overwrite_established_game(self):
        self.game()
        before = (self.root / "docs/game-guide/manifest.json").read_bytes()
        with self.assertRaises(ValueError): memory.initialize_guide(self.root)
        self.assertEqual(before, (self.root / "docs/game-guide/manifest.json").read_bytes())

    def test_new_scaffold_exports_without_claiming_source_review(self):
        self.game()
        path = self.root / "docs/game-guide/manifest.json"
        config = memory.read_json(path)
        config["source_baseline"] = {}
        config["reviewed_gameplay_ref"] = "Template-generated starter; game-specific mechanics not audited"
        memory.write(path, memory.json_text(config))
        memory.write(self.root / "docs/TEMPLATE_ORIGIN.md", "# Generated from known template\n")
        memory.initialize_guide(self.root)
        memory.export(self.root, check=True)
        self.assertIn("game-specific mechanics not audited", (self.root / "GAME_GUIDE.md").read_text())

    def test_network_failure_preserves_previous_snapshot(self):
        self.game()
        cache = self.root / ".local/team-memory/repository"; cache.mkdir(parents=True)
        saved = self.root / ".local/team-memory/snapshot.json"; memory.write(saved, memory.json_text(self.snapshot))
        before = saved.read_bytes()
        def failing_run(args, *unused, **kwargs):
            if "get-url" in args: return "https://github.com/Example/Notebook.git\n"
            raise ValueError("offline")
        with patch.object(memory, "run", side_effect=failing_run):
            with self.assertRaises(ValueError): memory.refresh(self.root)
        self.assertEqual(before, saved.read_bytes())

    def test_protected_software_change_cannot_auto_merge(self):
        self.library()
        pr = {"state": "open", "base": {"ref": "main"}, "head": {"repo": {"full_name": "Example/Notebook"}, "sha": "c" * 40}, "user": {"login": "teammate"}, "changed_files": 1}
        with patch.object(memory, "api", side_effect=[pr, [{"filename": "scripts/memory.py", "status": "modified"}]]) as calls:
            with self.assertRaisesRegex(ValueError, "protected"): memory.auto_publish(self.root, 1)
            self.assertEqual(calls.call_count, 2)

    def test_existing_lesson_cannot_auto_be_overwritten(self):
        self.library()
        pr = {"state": "open", "base": {"ref": "main"}, "head": {"repo": {"full_name": "Example/Notebook"}}, "user": {"login": "teammate"}, "changed_files": 1}
        with patch.object(memory, "api", side_effect=[pr, [{"filename": "lessons/test-route-lesson.json", "status": "modified"}]]):
            with self.assertRaisesRegex(ValueError, "protected"): memory.auto_publish(self.root, 1)

    def test_fork_cannot_auto_publish(self):
        self.library()
        pr = {"state": "open", "base": {"ref": "main"}, "head": {"repo": {"full_name": "Stranger/Notebook"}}, "user": {"login": "teammate"}}
        with patch.object(memory, "api", return_value=pr) as calls:
            with self.assertRaises(ValueError): memory.auto_publish(self.root, 1)
            self.assertEqual(calls.call_count, 1)


if __name__ == "__main__":
    unittest.main()
