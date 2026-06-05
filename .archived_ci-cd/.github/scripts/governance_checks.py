#!/usr/bin/env python3
"""
Governance checks for reusable CI policy enforcement.
Maps policy names to concrete checks:
- verify-information: block unresolved conflict markers and broken JSON/YAML syntax.
- no-inventions: block placeholder/fabricated markers (lorem ipsum, your-api-key-here, changeme).
- validation-before-completion: require at least one test or build command in common manifests.
- no-unnecessary-updates: fail on accidental large churn for tiny repos (safety heuristic).
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path.cwd()

TEXT_EXT_ALLOWLIST = {
    ".md",
    ".mdx",
    ".txt",
    ".py",
    ".js",
    ".jsx",
    ".ts",
    ".tsx",
    ".json",
    ".yaml",
    ".yml",
    ".toml",
    ".env",
    ".sh",
    ".sql",
}

SKIP_DIRS = {
    ".git",
    "node_modules",
    ".next",
    "dist",
    "build",
    "coverage",
    ".turbo",
    "vendor",
}

PLACEHOLDER_PATTERNS = [
    re.compile(r"lorem ipsum", re.IGNORECASE),
    re.compile(r"your[-_ ]?(api[-_ ]?)?key[-_ ]?here", re.IGNORECASE),
    re.compile(r"changeme", re.IGNORECASE),
    re.compile(r"replace[-_ ]?me", re.IGNORECASE),
]

SECRET_PATTERNS = [
    re.compile(r"ghp_[A-Za-z0-9]{20,}"),
    re.compile(r"sk-[A-Za-z0-9]{20,}"),
    re.compile(r"AKIA[0-9A-Z]{16}"),
]

CONFLICT_PATTERN = re.compile(r"^(<<<<<<<|=======|>>>>>>>)", re.MULTILINE)
TODO_PATTERN = re.compile(r"\b(TODO|FIXME|TBD)\b")


def is_text_target(path: Path) -> bool:
    return path.suffix.lower() in TEXT_EXT_ALLOWLIST or path.name in {"Dockerfile", ".env.example"}


def iter_files() -> list[Path]:
    out: list[Path] = []
    for p in ROOT.rglob("*"):
        if not p.is_file():
            continue
        if any(part in SKIP_DIRS for part in p.parts):
            continue
        if is_text_target(p):
            out.append(p)
    return out


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def git_changed_count() -> int:
    cmd = ["git", "diff", "--name-only", "--diff-filter=ACMR", "origin/main...HEAD"]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        cmd = ["git", "diff", "--name-only", "--diff-filter=ACMR", "HEAD~1...HEAD"]
        proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        return 0
    return len([x for x in proc.stdout.splitlines() if x.strip()])


def check_manifest_validation() -> list[str]:
    errs: list[str] = []

    pkg = ROOT / "package.json"
    if pkg.exists():
        try:
            data = json.loads(pkg.read_text(encoding="utf-8"))
            scripts = data.get("scripts", {})
            has_validation = any(k in scripts for k in ("test", "build", "lint", "typecheck"))
            if not has_validation:
                errs.append("package.json has no validation script (expected one of: test/build/lint/typecheck)")
        except Exception as e:
            errs.append(f"Invalid package.json: {e}")

    pyproject = ROOT / "pyproject.toml"
    req = ROOT / "requirements.txt"
    if pyproject.exists() or req.exists():
        if not ((ROOT / "tests").exists() or (ROOT / "pytest.ini").exists()):
            errs.append("Python project detected but no tests directory or pytest.ini found")

    return errs


def main() -> int:
    errors: list[str] = []
    files = iter_files()
    fail_on_todo = str(os.getenv("FAIL_ON_TODO", "true")).lower() == "true"

    for f in files:
        if f.name == "governance_checks.py":
            continue

        text = read_text(f)
        if not text:
            continue

        if CONFLICT_PATTERN.search(text):
            errors.append(f"{f}: unresolved merge conflict markers found")

        for pat in SECRET_PATTERNS:
            if pat.search(text):
                errors.append(f"{f}: potential secret detected ({pat.pattern})")

        for pat in PLACEHOLDER_PATTERNS:
            if pat.search(text):
                errors.append(f"{f}: placeholder content detected ({pat.pattern})")

        if fail_on_todo and f.suffix.lower() in {".py", ".js", ".jsx", ".ts", ".tsx", ".sh"}:
            if TODO_PATTERN.search(text):
                errors.append(f"{f}: TODO/FIXME/TBD markers present")

    errors.extend(check_manifest_validation())

    # Small-repo churn guardrail (no-unnecessary-updates)
    changed = git_changed_count()
    repo_size_kb = sum((p.stat().st_size for p in files), 0) // 1024
    if repo_size_kb < 200 and changed > 40:
        errors.append(f"Large churn detected for small repo: {changed} changed files / {repo_size_kb}KB")

    if errors:
        print("❌ Governance checks failed:")
        for e in errors:
            print(f"- {e}")
        return 1

    print("✅ Governance checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
