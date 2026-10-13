"""Team notebook and portable game guides. Python standard library; no game runtime code.

Shared lessons are data, never executable instructions. Network operations use the
teammate's existing Git/GitHub sign-in. Check/export work offline from saved inputs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

VERSION = 1
NOTE_ID = re.compile(r"^[a-z0-9][a-z0-9-]{4,90}$")
REPO = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
EVIDENCE = {"source-review", "automated-test", "studio-test", "human-feedback", "measurement"}


def run(args, cwd=None, stdin=None):
    result = subprocess.run(args, cwd=cwd, input=stdin, capture_output=True, text=True, encoding="utf-8")
    if result.returncode:
        raise ValueError(f"{args[0]} could not complete this step: {result.stderr.strip() or result.stdout.strip()}")
    return result.stdout


def api(path, data=None, method=None):
    args = ["gh", "api", path]
    if method:
        args += ["--method", method]
    if data is not None:
        args += ["--input", "-"]
    response = run(args, stdin=json.dumps(data) if data is not None else None)
    return json.loads(response) if response.strip() else {}


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(text, encoding="utf-8", newline="\n")
    temporary.replace(path)


def json_text(value):
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def text_hash(path):
    # Git may check out CRLF on Windows and LF in CI. Documentation freshness
    # tracks content, not the workstation's newline convention or UTF-8 BOM.
    return hashlib.sha256(path.read_text(encoding="utf-8-sig").encode("utf-8")).hexdigest()


def safe_path(root, relative):
    if not isinstance(relative, str) or "\\" in relative:
        raise ValueError("Use a repository-relative path with forward slashes.")
    target = (root / relative).resolve()
    if target == root.resolve() or root.resolve() not in target.parents:
        raise ValueError(f"Path escapes the project: {relative}")
    return target


def validate_note(note):
    if not isinstance(note, dict) or note.get("schema_version") != VERSION:
        raise ValueError("Unsupported lesson format; preserve it and ask the AI to update the helper.")
    for key in ("id", "title", "observation", "recommendation", "game", "date"):
        if not isinstance(note.get(key), str) or not note[key].strip():
            raise ValueError(f"Lesson needs {key}.")
    if not NOTE_ID.fullmatch(note["id"]):
        raise ValueError("Lesson ID must be a descriptive lowercase slug.")
    if not REPO.fullmatch(note["game"]):
        raise ValueError("Lesson game must be owner/repository.")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", note["date"]):
        raise ValueError("Lesson date must be YYYY-MM-DD.")
    if note.get("status") not in ("observation", "hypothesis"):
        raise ValueError("Automatic notes must remain observations or hypotheses, not universal rules.")
    for key in ("topics", "applies_when", "limits", "evidence"):
        if not isinstance(note.get(key), list) or not note[key]:
            raise ValueError(f"Lesson needs a nonempty {key} list.")
    for key in ("topics", "applies_when", "limits"):
        if any(not isinstance(item, str) or not item.strip() for item in note[key]):
            raise ValueError(f"Invalid {key} entry.")
    for check in note.get("rubric_checks", []):
        if not isinstance(check, str) or not re.fullmatch(r"CL-\d{2}", check):
            raise ValueError("Invalid clarity checklist reference.")
    for evidence in note["evidence"]:
        if not isinstance(evidence, dict) or evidence.get("kind") not in EVIDENCE:
            raise ValueError("Evidence needs an explicit test/observation method.")
        if not isinstance(evidence.get("detail"), str) or not evidence["detail"].strip():
            raise ValueError("Evidence needs an actual result or attributed observation.")
        url = evidence.get("url", "")
        if not isinstance(url, str) or not re.fullmatch(r"https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/blob/[a-f0-9]{40}/[^\s]+", url):
            raise ValueError("Evidence must link a durable GitHub file at an exact commit.")
    if len(json_text(note).encode("utf-8")) > 16000:
        raise ValueError("Keep a lesson focused; put detailed history in the game's report.")


def validate_library(config, baseline, notes):
    if config.get("schema_version") != VERSION or not REPO.fullmatch(config.get("repository", "")):
        raise ValueError("Unsupported or invalid library configuration.")
    ids = set()
    for note in notes:
        validate_note(note)
        if note["id"] in ids:
            raise ValueError(f"Duplicate lesson ID: {note['id']}")
        ids.add(note["id"])
        for check in note.get("rubric_checks", []):
            if check not in baseline:
                raise ValueError(f"Unknown rubric check {check}.")
    return notes


def load_library(root):
    config = read_json(root / "library.json")
    baseline = (root / "rubric/BASE.md").read_text(encoding="utf-8")
    notes = []
    for path in sorted((root / "lessons").glob("*.json")):
        note = read_json(path)
        validate_note(note)
        if path.stem != note["id"]:
            raise ValueError("Lesson filename must match its ID.")
        notes.append(note)
    validate_library(config, baseline, notes)
    return config, baseline, notes


def render_rubric(baseline, notes):
    lines = ["<!-- Generated by scripts/memory.py library-build. Edit rubric/BASE.md or add attributed lessons. -->", baseline.rstrip(), "", "## Team learning additions", "", "These are attributed observations and hypotheses, not automatic changes to the core standards. Apply their context and limits. New evidence may challenge them; never turn a game preference into a universal requirement.", ""]
    for note in sorted(notes, key=lambda n: (n["date"], n["id"]), reverse=True):
        lines += [f"### {note['title']}", "", f"**ID:** {note['id']} | **Status:** {note['status']} | **Game:** {note['game']} | **Date:** {note['date']}", f"**Related checks:** {', '.join(note.get('rubric_checks', [])) or 'General'}", "", f"**Observed / proposed:** {note['observation']}", "", f"**Recommendation:** {note['recommendation']}", "", "**Applies when:** " + "; ".join(note["applies_when"]), "", "**Limits:** " + "; ".join(note["limits"]), ""]
        for evidence in note["evidence"]:
            lines += [f"- [{evidence['kind']}]({evidence['url']}): {evidence['detail']}"]
        lines += [""]
    return "\n".join(lines).rstrip() + "\n"


def render_index(notes):
    lines = ["# Shared lesson index", "", "Generated from immutable lesson records. Read the applicable evidence and limits in QUALITY_RUBRIC.md.", ""]
    for note in sorted(notes, key=lambda n: n["id"]):
        lines.append(f"- **{note['title']}** ({', '.join(note['topics'])}; {note['status']}): [record](lessons/{note['id']}.json)")
    return "\n".join(lines) + "\n"


def library_outputs(root, check=False):
    _, baseline, notes = load_library(root)
    outputs = {"QUALITY_RUBRIC.md": render_rubric(baseline, notes), "INDEX.md": render_index(notes)}
    for name, content in outputs.items():
        path = root / name
        if check:
            if not path.exists() or path.read_text(encoding="utf-8") != content:
                raise ValueError(f"Shared {name} is stale; run library-build.")
        else:
            write(path, content)
    return outputs


def snapshot_from_git(cache, revision):
    def content(path):
        return run(["git", "show", f"{revision}:{path}"], cache)
    config = json.loads(content("library.json"))
    baseline = content("rubric/BASE.md")
    paths = run(["git", "ls-tree", "-r", "--name-only", revision], cache).splitlines()
    notes = []
    for path in paths:
        if re.fullmatch(r"lessons/[a-z0-9-]+\.json", path):
            note = json.loads(content(path))
            if path != f"lessons/{note.get('id')}.json":
                raise ValueError("Lesson path and ID disagree.")
            notes.append(note)
    validate_library(config, baseline, notes)
    if content("QUALITY_RUBRIC.md") != render_rubric(baseline, notes) or content("INDEX.md") != render_index(notes):
        raise ValueError("Shared library generated files are stale; preserve the last good snapshot.")
    return {"schema_version": VERSION, "repository": config["repository"], "revision": revision, "baseline": baseline, "notes": notes}


def project_config(root):
    config = read_json(root / "docs/game-guide/manifest.json")
    if config.get("schema_version") != VERSION or not REPO.fullmatch(config.get("repository", "")) or not REPO.fullmatch(config.get("knowledge_repository", "")):
        raise ValueError("Invalid game guide manifest.")
    return config


def refresh(root):
    config = project_config(root)
    cache = root / ".local/team-memory/repository"
    cache.parent.mkdir(parents=True, exist_ok=True)
    if not cache.exists():
        run(["git", "clone", "--no-checkout", f"https://github.com/{config['knowledge_repository']}.git", str(cache)])
    remote = run(["git", "remote", "get-url", "origin"], cache).strip()
    if remote != f"https://github.com/{config['knowledge_repository']}.git":
        raise ValueError("The notebook cache points to a different repository; preserve it and ask the AI to repair it.")
    run(["git", "fetch", "origin", "main"], cache)
    revision = run(["git", "rev-parse", "FETCH_HEAD"], cache).strip()
    snapshot = snapshot_from_git(cache, revision)
    if snapshot["repository"] != config["knowledge_repository"]:
        raise ValueError("Unexpected library identity.")
    write(root / ".local/team-memory/snapshot.json", json_text(snapshot))
    write(root / ".local/team-memory/QUALITY_RUBRIC.md", render_rubric(snapshot["baseline"], snapshot["notes"]))
    print(f"Checked shared lessons at {revision[:12]}; {len(snapshot['notes'])} lessons. Read .local/team-memory/QUALITY_RUBRIC.md.")
    return snapshot


def source_hashes(root):
    sources = sorted(p for p in (root / "src").rglob("*") if p.is_file() and p.suffix in (".lua", ".luau"))
    if (root / "default.project.json").exists():
        sources += [root / "default.project.json"]
    return {p.relative_to(root).as_posix(): text_hash(p) for p in sources}


def guide_outputs(root, snapshot=None):
    config = project_config(root)
    for path in (root / "docs/learning").glob("*.json"):
        pending = read_json(path)
        validate_note(pending)
        if pending["game"] != config["repository"] or pending["id"] != path.stem:
            raise ValueError("A local lesson does not match this game's identity.")
    actual = source_hashes(root)
    if actual != config.get("source_baseline"):
        changed = sorted(k for k in actual.keys() | config.get("source_baseline", {}).keys() if actual.get(k) != config.get("source_baseline", {}).get(k))
        raise ValueError("Game source changed since the guide baseline: " + ", ".join(changed) + ". Inspect affected mechanics, update the game description/evidence, then update those baseline fingerprints. Fingerprints do not establish code inspection or gameplay tests.")
    if snapshot is None:
        snapshot = read_json(root / "docs/team-memory-snapshot.json")
    if snapshot.get("schema_version") != VERSION or snapshot.get("repository") != config["knowledge_repository"]:
        raise ValueError("Invalid shared snapshot for this game.")
    validate_library({"schema_version": VERSION, "repository": snapshot["repository"]}, snapshot["baseline"], snapshot["notes"])
    input_paths = list(config["chapters"]) + list(config["appendices"])
    reports = sorted((root / "docs/reports").glob("*.md"), reverse=True)
    reports = [p for p in reports if p.name != "README.md"]
    rubric = render_rubric(snapshot["baseline"], snapshot["notes"])
    hashes = {relative: text_hash(safe_path(root, relative)) for relative in input_paths}
    hashes.update({p.relative_to(root).as_posix(): text_hash(p) for p in reports})
    fingerprint = hashlib.sha256(json_text({"manifest": config, "inputs": hashes, "knowledge": snapshot}).encode("utf-8")).hexdigest()
    lines = [f"# {config['game_name']} — complete game guide", "", "<!-- Generated by scripts/memory.py export. Edit the sources listed in docs/game-guide/manifest.json (normally docs/GAME_DESIGN.md), then regenerate. -->", "", "## How to use this file with any AI", "", "This file is a self-contained game description, quality rubric, and dated development history. Use it for coherent ideas and critique without the original chat. The current game description covers this branch; dated reports describe historical revisions and never override it. Mentioned plans are not implemented unless explicitly identified that way. Silence about a feature means undocumented, not confirmed absent. Source review, automated tests, Studio tests, human feedback, and release approval are different evidence levels. To confirm bugs or runtime behavior, inspect the actual code and relevant tests; this description is not runtime proof.", "", f"**Game repository:** https://github.com/{config['repository']}", f"**Documented gameplay revision:** {config['reviewed_gameplay_ref']}", f"**Shared rubric revision:** {snapshot['revision']}", f"**Document freshness fingerprint:** {fingerprint}", "", "Ask an outside AI: 'Read this complete guide, compare the current game with the included rubric, and suggest the highest-value improvements. Separate documented gaps, hypotheses, and ideas. Respect game-specific decisions and current prototype gates.'", ""]
    for relative in input_paths:
        path = safe_path(root, relative)
        lines += ["---", "", f"<!-- Source: {relative} -->", ""]
        if path.suffix in (".lua", ".luau", ".json"):
            lines += [f"## Exact tuning / mapping: {relative}", "", "These are current source values, not evidence that the balance or platform experience feels good.", "", "```" + ("json" if path.suffix == ".json" else "lua"), path.read_text(encoding="utf-8").rstrip(), "```", ""]
        else:
            lines += [path.read_text(encoding="utf-8").rstrip(), ""]
    lines += ["---", "", "# Shared quality rubric and cross-game lessons", "", rubric.rstrip(), "", "---", "", "# Development changelog and historical test reports", "", "Reports below are preserved in full, newest first. A historical test pass applies to that recorded revision and environment. Old priorities, controls, limitations, and status may have been superseded by the current game description above.", ""]
    for path in reports:
        lines += ["---", "", f"## Report: {path.name}", "", path.read_text(encoding="utf-8").rstrip(), ""]
    return {"GAME_GUIDE.md": "\n".join(lines).rstrip() + "\n", "QUALITY_RUBRIC.md": rubric, "docs/game-guide/freshness.json": json_text({"schema_version": VERSION, "fingerprint": fingerprint, "source_baseline": actual, "inputs": hashes, "knowledge_revision": snapshot["revision"]})}


def export(root, check=False):
    snapshot_path = root / ".local/team-memory/snapshot.json"
    snapshot = read_json(snapshot_path) if not check and snapshot_path.exists() else None
    outputs = guide_outputs(root, snapshot)
    if not check and snapshot is not None:
        write(root / "docs/team-memory-snapshot.json", json_text(snapshot))
    for name, content in outputs.items():
        path = root / name
        if check:
            if not path.exists() or path.read_text(encoding="utf-8") != content:
                raise ValueError(f"{name} is stale. Update the game records and run export.")
        else:
            write(path, content)
    print("Game guide and rubric match their saved inputs. Source fingerprints do not certify inspection or gameplay tests." if check else "Updated GAME_GUIDE.md and QUALITY_RUBRIC.md. Both are ready to attach to another AI; the guide includes the rubric and full report history.")


def initialize_guide(root):
    config = project_config(root)
    if config.get("source_baseline") or config.get("reviewed_gameplay_ref") != "Template-generated starter; game-specific mechanics not audited":
        raise ValueError("Initialization is only for a new template scaffold; preserve existing game records.")
    if not (root / "docs/TEMPLATE_ORIGIN.md").exists():
        raise ValueError("Missing template origin; cannot establish new-scaffold provenance.")
    # This is a generated starter snapshot, explicitly not a source-review stamp.
    config["source_baseline"] = source_hashes(root)
    write(root / "docs/game-guide/manifest.json", json_text(config))
    export(root)


def submit(root):
    config = project_config(root)
    snapshot = refresh(root)
    repo = config["knowledge_repository"]
    existing = {n["id"]: n for n in snapshot["notes"]}
    additions = []
    for path in sorted((root / "docs/learning").glob("*.json")):
        note = read_json(path)
        validate_note(note)
        if path.stem != note["id"] or note["game"] != config["repository"]:
            raise ValueError("Local lesson identity or game does not match its project.")
        if note["id"] in existing:
            if note != existing[note["id"]]:
                raise ValueError(f"Shared {note['id']} differs; preserve both and reconcile, never overwrite.")
        else:
            additions.append(note)
    if not additions:
        print("No unshared local lessons; confirmed matching records are already in the notebook.")
        return
    if len(additions) > 12:
        raise ValueError("Submit at most twelve focused lessons in one batch.")
    for note in additions:
        for evidence in note["evidence"]:
            match = re.fullmatch(r"https://github\.com/([^/]+/[^/]+)/blob/([a-f0-9]{40})/(.+)", evidence["url"])
            api(f"repos/{match[1]}/contents/{match[3]}?ref={match[2]}")
    all_notes = snapshot["notes"] + additions
    validate_library({"schema_version": VERSION, "repository": repo}, snapshot["baseline"], all_notes)
    # Batch identity lets a retry discover its own open PR without duplicate publication.
    batch = hashlib.sha256(json_text(sorted(additions, key=lambda n: n["id"])).encode("utf-8")).hexdigest()[:16]
    branch = f"learning/{batch}"
    opens = api(f"repos/{repo}/pulls?state=open&head={repo.split('/')[0]}:{branch}")
    if opens:
        api(f"repos/{repo}/actions/workflows/publish.yml/dispatches", {"ref": "main", "inputs": {"pr": str(opens[0]['number'])}})
        print(f"Lessons remain pending in {opens[0]['html_url']}; do not claim they are shared on main yet.")
        return
    base = api(f"repos/{repo}/git/commits/{snapshot['revision']}")
    tree = [{"path": f"lessons/{n['id']}.json", "mode": "100644", "type": "blob", "content": json_text(n)} for n in additions]
    tree += [{"path": "QUALITY_RUBRIC.md", "mode": "100644", "type": "blob", "content": render_rubric(snapshot["baseline"], all_notes)}, {"path": "INDEX.md", "mode": "100644", "type": "blob", "content": render_index(all_notes)}]
    new_tree = api(f"repos/{repo}/git/trees", {"base_tree": base["tree"]["sha"], "tree": tree})
    commit = api(f"repos/{repo}/git/commits", {"message": "Record attributed cross-game lessons", "tree": new_tree["sha"], "parents": [snapshot["revision"]]})
    try:
        api(f"repos/{repo}/git/refs", {"ref": f"refs/heads/{branch}", "sha": commit["sha"]})
    except ValueError:
        ref = api(f"repos/{repo}/git/ref/heads/{branch}")
        if ref["object"]["sha"] != commit["sha"]:
            # A prior interrupted submission is safe only if its files match this exact batch.
            for note in additions:
                saved = api(f"repos/{repo}/contents/lessons/{note['id']}.json?ref={branch}")
                import base64
                if json.loads(base64.b64decode(saved["content"]).decode("utf-8")) != note:
                    raise ValueError("An earlier publication differs; preserve it for reconciliation.")
    pr = api(f"repos/{repo}/pulls", {"title": "Learning: " + "; ".join(n["title"] for n in additions)[:180], "head": branch, "base": "main", "body": "Automatic lesson-only submission under the agreed notebook policy. Original game evidence is linked at exact revisions. No gameplay, baseline standards, or team rules are changed. Validation will publish safe additions; conflicts remain pending."})
    print(f"Created lesson submission: {pr['html_url']}. It is pending until validation and merge succeed.")


def auto_publish(root, number):
    config, _, _ = load_library(root)
    repo = config["repository"]
    pr = api(f"repos/{repo}/pulls/{number}")
    if pr["state"] != "open" or pr["base"]["ref"] != "main" or pr["head"]["repo"]["full_name"] != repo or pr["user"]["login"].lower() not in {x.lower() for x in config["automatic_authors"]}:
        raise ValueError("This PR needs normal human review; automatic publication is only for teammate lesson additions.")
    if pr["changed_files"] > 14:
        raise ValueError("Publication batch is too large.")
    files = api(f"repos/{repo}/pulls/{number}/files?per_page=100")
    if len(files) != pr["changed_files"]:
        raise ValueError("Incomplete changed-file list; no automatic merge.")
    added = 0
    for file in files:
        if re.fullmatch(r"lessons/[a-z0-9-]+\.json", file["filename"]) and file["status"] == "added":
            added += 1
        elif file["filename"] in ("QUALITY_RUBRIC.md", "INDEX.md") and file["status"] == "modified":
            pass
        else:
            raise ValueError("PR changes protected rules, existing lessons, or software; human review required.")
    if not 1 <= added <= 12:
        raise ValueError("Expected one to twelve new lessons.")
    run(["git", "fetch", "origin", pr["head"]["sha"]], root)
    proposed = snapshot_from_git(root, pr["head"]["sha"])
    latest = api(f"repos/{repo}/git/ref/heads/main")["object"]["sha"]
    run(["git", "fetch", "origin", latest], root)
    current = snapshot_from_git(root, latest)
    if proposed["baseline"] != current["baseline"]:
        raise ValueError("Base quality standards changed during publication; review the lessons against them.")
    existing = {n["id"]: n for n in current["notes"]}
    new_notes = []
    proposed_by_id = {n["id"]: n for n in proposed["notes"]}
    for file in files:
        if file["status"] == "added":
            candidate = proposed_by_id[Path(file["filename"]).stem]
            if candidate["id"] in existing:
                if candidate != existing[candidate["id"]]:
                    raise ValueError("A concurrently published lesson differs; preserve both for review.")
            else:
                new_notes.append(candidate)
    if not new_notes:
        api(f"repos/{repo}/pulls/{number}", {"state": "closed"}, "PATCH")
        print("This exact lesson batch is already published; closed the redundant submission.")
        return
    head = pr["head"]["sha"]
    combined_by_id = {n["id"]: n for n in current["notes"] + new_notes}
    if latest != pr["base"]["sha"] or pr.get("mergeable") is False or proposed_by_id != combined_by_id:
        # Recombine independent additions on the latest main. The new commit has
        # both parents and moves the submission branch forward, never force-pushes.
        notes = current["notes"] + new_notes
        base = api(f"repos/{repo}/git/commits/{latest}")
        tree = [{"path": f"lessons/{n['id']}.json", "mode": "100644", "type": "blob", "content": json_text(n)} for n in new_notes]
        tree += [{"path": "QUALITY_RUBRIC.md", "mode": "100644", "type": "blob", "content": render_rubric(current["baseline"], notes)}, {"path": "INDEX.md", "mode": "100644", "type": "blob", "content": render_index(notes)}]
        merged_tree = api(f"repos/{repo}/git/trees", {"base_tree": base["tree"]["sha"], "tree": tree})
        commit = api(f"repos/{repo}/git/commits", {"message": "Combine independent lesson additions with current notebook", "tree": merged_tree["sha"], "parents": [head, latest]})
        api(f"repos/{repo}/git/refs/heads/{pr['head']['ref']}", {"sha": commit["sha"], "force": False}, "PATCH")
        head = commit["sha"]
    import time
    for attempt in range(6):
        state = api(f"repos/{repo}/pulls/{number}")
        if state["head"]["sha"] != head:
            raise ValueError("Submission changed during validation; retry the new head.")
        if state.get("mergeable") is True:
            break
        if state.get("mergeable") is False:
            raise ValueError("Publication still conflicts; preserve it for review.")
        time.sleep(2)
    else:
        raise ValueError("Mergeability is still unknown; retry this pending submission later.")
    result = api(f"repos/{repo}/pulls/{number}/merge", {"sha": head, "merge_method": "squash", "commit_title": pr["title"]}, "PUT")
    if not result.get("merged"):
        raise ValueError("Publication not confirmed; leave lessons pending.")
    print(f"Published validated lesson additions in PR #{number}.")
    # Delete only this completed submission branch; never a gameplay or default branch.
    if pr["head"]["ref"].startswith("learning/"):
        api(f"repos/{repo}/git/refs/heads/{pr['head']['ref']}", method="DELETE")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("read", "submit", "init", "export", "check", "test", "library-build", "library-check", "auto-publish"))
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--pr", type=int)
    args = parser.parse_args()
    root = args.root.resolve()
    if args.action == "read":
        refresh(root)
    elif args.action == "init":
        initialize_guide(root)
    elif args.action == "submit":
        submit(root)
    elif args.action in ("export", "check"):
        export(root, check=args.action == "check")
    elif args.action == "test":
        import unittest
        suite = unittest.defaultTestLoader.discover(str(root / "tests"), pattern="test_memory.py")
        if not unittest.TextTestRunner().run(suite).wasSuccessful():
            raise ValueError("Memory regression checks failed.")
    elif args.action in ("library-build", "library-check"):
        library_outputs(root, check=args.action == "library-check")
        print("Shared rubric, evidence records, and index validated.")
    elif args.action == "auto-publish":
        if not args.pr:
            raise ValueError("Missing PR number.")
        auto_publish(root, args.pr)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(f"Memory needs attention: {error}", file=sys.stderr)
        print("Keep existing records. The AI should repair this step; do not claim fresh knowledge or successful publication.", file=sys.stderr)
        sys.exit(1)
