#!/usr/bin/env python3
"""
Coverage Triage - Below Threshold

Generate triage CSVs for methods below a given coverage threshold using the
`crap-scores.csv` output produced by the DataMigrator enhanced coverage analysis.

This script supports both local execution and CI/CD environments.

Features:
    - Comprehensive CLI (`--help`) with portable defaults
    - Optional JSON config file support (useful for repeatable CI runs)
    - Strong input validation and actionable error messages
    - Deterministic CSV output for triage workflows

Usage:
    Basic (local):
        $ python coverage-triage-below-threshold.py --csv path/to/crap-scores.csv

    Custom threshold and output dir:
        $ python coverage-triage-below-threshold.py --csv path/to/crap-scores.csv --max-coverage 40 --out-dir out/

    With JSON config:
        $ python coverage-triage-below-threshold.py --config-file coverage-triage.json --csv path/to/crap-scores.csv

Example Azure Pipelines usage:
    - task: PythonScript@0
      inputs:
        scriptPath: '.cursor/scripts/unit-testing/coverage-triage-below-threshold.py'
        arguments: '--csv $(Build.SourcesDirectory)/path/to/crap-scores.csv --max-coverage 50 --out-dir $(Build.ArtifactStagingDirectory)/coverage-triage'

Requirements:
    - Python 3.9+
    - No external packages (stdlib only)

Config file (JSON) keys (all optional; CLI overrides config):
    - out_dir: string (path)
    - max_coverage: number (exclusive upper bound, 0 < x <= 100)
    - assembly: string
    - actionable_filter: boolean
    - preview_limit: integer (>= 0)
"""

from __future__ import annotations

import argparse
import csv
import json
import logging
import os
import sys
from dataclasses import dataclass
from enum import IntEnum
from pathlib import Path
from typing import Any, Iterable, Mapping


@dataclass(frozen=True)
class CoverageRow:
    assembly: str
    class_name: str
    method: str
    crap_score: float
    complexity: int
    coverage: float
    full_class_name: str
    full_method_name: str


__version__ = "1.1.0"


class ExitCode(IntEnum):
    success = 0
    general_error = 1
    config_error = 2
    validation_error = 4
    runtime_error = 5


class ScriptError(RuntimeError):
    def __init__(
        self,
        *,
        exit_code: ExitCode,
        title: str,
        explanation: str,
        solution: str,
        location: str | None = None,
        help_text: str | None = None,
    ) -> None:
        super().__init__(title)
        self.exit_code = exit_code
        self.title = title
        self.explanation = explanation
        self.solution = solution
        self.location = location
        self.help_text = help_text

    def format_diagnostic(self) -> str:
        parts: list[str] = [
            f"ERROR: {self.title}",
            "",
            f"Explanation: {self.explanation}",
            "",
            f"Solution: {self.solution}",
        ]
        if self.location:
            parts.extend(["", f"Location: {self.location}"])
        if self.help_text:
            parts.extend(["", f"Help: {self.help_text}"])
        return "\n".join(parts)


def is_azure_pipelines() -> bool:
    return bool(os.getenv("AGENT_TEMPDIRECTORY"))


def setup_logging(*, verbose: bool) -> logging.Logger:
    logger = logging.getLogger("coverage-triage-below-threshold")
    logger.handlers.clear()
    logger.setLevel(logging.DEBUG if verbose else logging.INFO)

    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(logging.DEBUG if verbose else logging.INFO)
    handler.setFormatter(logging.Formatter("%(levelname)s: %(message)s"))
    logger.addHandler(handler)

    return logger


def emit_azure_pipeline_error(message: str) -> None:
    # Azure Pipelines recognizes these commands in stdout/stderr.
    if is_azure_pipelines():
        sys.stdout.write(f"##vso[task.logissue type=error]{message}\n")
        sys.stdout.flush()


def _require_headers(reader: csv.DictReader, required: set[str], *, csv_path: Path) -> None:
    missing = sorted(required.difference(reader.fieldnames or []))
    if missing:
        raise ScriptError(
            exit_code=ExitCode.validation_error,
            title="Input CSV is missing required columns",
            explanation=(
                "The input file does not match the expected 'crap-scores.csv' schema produced by the enhanced coverage analysis."
            ),
            solution=(
                "Re-run the enhanced coverage analysis to regenerate 'crap-scores.csv', or provide the correct file.\n"
                f"Missing columns: {', '.join(missing)}"
            ),
            location=str(csv_path),
            help_text="Provide the path via --csv (see --help for examples).",
        )


def parse_rows(csv_path: Path) -> list[CoverageRow]:
    required = {
        "Assembly",
        "Class",
        "Method",
        "CrapScore",
        "Complexity",
        "Coverage",
        "FullClassName",
        "FullMethodName",
    }

    try:
        with csv_path.open(newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            _require_headers(reader, required, csv_path=csv_path)

            rows: list[CoverageRow] = []
            for r in reader:
                try:
                    rows.append(
                        CoverageRow(
                            assembly=r["Assembly"],
                            class_name=r["Class"],
                            method=r["Method"],
                            crap_score=float(r["CrapScore"]),
                            complexity=int(float(r["Complexity"])),
                            coverage=float(r["Coverage"]),
                            full_class_name=r["FullClassName"],
                            full_method_name=r["FullMethodName"],
                        )
                    )
                except (KeyError, ValueError, TypeError) as ex:
                    raise ScriptError(
                        exit_code=ExitCode.validation_error,
                        title="Failed to parse a row from the input CSV",
                        explanation="At least one row contains missing or non-numeric values in required columns.",
                        solution=(
                            "Inspect the input CSV around the failing row and fix the data, or regenerate the file.\n"
                            "Tip: ensure CrapScore/Complexity/Coverage are numeric."
                        ),
                        location=str(csv_path),
                        help_text=str(ex),
                    ) from ex

            return rows
    except FileNotFoundError as ex:
        raise ScriptError(
            exit_code=ExitCode.validation_error,
            title="Input CSV file was not found",
            explanation="The provided --csv path does not exist or is not accessible.",
            solution="Provide a valid path to 'crap-scores.csv' via --csv.",
            location=str(csv_path),
        ) from ex


def is_actionable(row: CoverageRow) -> bool:
    # Exclude constructors, property accessors, operators, and compiler-generated names.
    if row.method in (".ctor", ".cctor"):
        return False
    if row.method.startswith(("get_", "set_", "op_")):
        return False
    if "<" in row.full_method_name and ">" in row.full_method_name:
        return False
    return True


def below_coverage(rows: Iterable[CoverageRow], max_coverage_exclusive: float) -> list[CoverageRow]:
    return [r for r in rows if r.coverage < max_coverage_exclusive]


def sort_for_triage(rows: Iterable[CoverageRow]) -> list[CoverageRow]:
    # Lowest coverage first; then highest CRAP score; then highest cyclomatic complexity.
    return sorted(
        rows,
        key=lambda r: (r.coverage, -r.crap_score, -r.complexity, r.assembly, r.full_class_name, r.method),
    )


def write_csv(path: Path, rows: Iterable[CoverageRow]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    with path.open("w", newline="", encoding="utf-8") as f:
        # Preserve the previous output shape:
        # - header row not quoted
        # - all string fields quoted
        # - numeric fields not quoted
        f.write("Assembly,FullClassName,Method,Coverage,CrapScore,Complexity,FullMethodName\n")
        writer = csv.writer(f, quoting=csv.QUOTE_NONNUMERIC)
        for r in rows:
            writer.writerow(
                [r.assembly, r.full_class_name, r.method, r.coverage, r.crap_score, r.complexity, r.full_method_name]
            )

def render_console_preview(logger: logging.Logger, title: str, rows: list[CoverageRow], *, limit: int) -> None:
    logger.info("")
    logger.info(title)
    logger.info("-" * len(title))
    logger.info("Count: %d", len(rows))
    for r in rows[:limit]:
        logger.info(
            "%6.1f%% | CRAP %7.2f | CC %2d | %s | %s.%s",
            r.coverage,
            r.crap_score,
            r.complexity,
            r.assembly,
            r.full_class_name,
            r.method,
        )
    if len(rows) > limit:
        logger.info("... %d more", len(rows) - limit)


def _load_json_config(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError as ex:
        raise ScriptError(
            exit_code=ExitCode.config_error,
            title="Config file was not found",
            explanation="The provided --config-file path does not exist or is not accessible.",
            solution="Provide a valid JSON config file path, or omit --config-file.",
            location=str(path),
        ) from ex
    except json.JSONDecodeError as ex:
        raise ScriptError(
            exit_code=ExitCode.config_error,
            title="Config file is not valid JSON",
            explanation="The config file could not be parsed as JSON.",
            solution="Fix the JSON syntax (or provide a different config file) and re-run the script.",
            location=f"{path}:{ex.lineno}:{ex.colno}",
            help_text=ex.msg,
        ) from ex

    if not isinstance(data, dict):
        raise ScriptError(
            exit_code=ExitCode.config_error,
            title="Config file root must be a JSON object",
            explanation="The script expects a JSON object with simple key/value pairs.",
            solution="Update the config file so the root is an object (e.g. {\"max_coverage\": 50}).",
            location=str(path),
        )

    return data


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate triage lists for methods below a given coverage threshold using enhanced-coverage-analysis crap-scores.csv."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  %(prog)s --csv tickets/.../work/coverage-YYYY-MM-DD-N/crap-scores.csv\n"
            "  %(prog)s --csv crap-scores.csv --max-coverage 40 --out-dir out/\n"
            "  %(prog)s --config-file coverage-triage.json --csv crap-scores.csv\n"
        ),
    )
    parser.add_argument(
        "--csv",
        required=True,
        help="Path to crap-scores.csv (e.g. tickets/.../work/coverage-YYYY-MM-DD-N/crap-scores.csv)",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=None,
        help="Output directory for generated CSVs (default: current directory; can be set via config).",
    )
    parser.add_argument(
        "--max-coverage",
        type=float,
        default=None,
        help="Exclusive upper bound for coverage percentage (default: 50.0 means < 50; can be set via config).",
    )
    parser.add_argument(
        "--assembly",
        default=None,
        help="Assembly name to generate an assembly-specific list for (default: Eneve.eBase.DataMigrator; can be set via config).",
    )

    actionable_group = parser.add_mutually_exclusive_group()
    actionable_group.add_argument(
        "--actionable-filter",
        dest="actionable_filter",
        action="store_const",
        const=True,
        default=None,
        help="Filter out constructors/property accessors/operators/compiler-generated names (default).",
    )
    actionable_group.add_argument(
        "--no-actionable-filter",
        dest="actionable_filter",
        action="store_const",
        const=False,
        default=None,
        help="Do not filter out constructors/property accessors/operators/compiler-generated names.",
    )

    parser.add_argument(
        "--preview-limit",
        type=int,
        default=None,
        help="Max number of preview rows to print per section (default: 50; can be set via config).",
    )
    parser.add_argument(
        "--config-file",
        type=Path,
        default=None,
        help="Optional JSON config file path (CLI arguments override config).",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose (debug) logging.",
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {__version__}",
    )
    return parser.parse_args()


def _coalesce_config(
    raw_config: Mapping[str, Any],
    args: argparse.Namespace,
) -> tuple[Path, Path, float, str, bool, int]:
    allowed_keys = {"out_dir", "max_coverage", "assembly", "actionable_filter", "preview_limit"}
    unknown = sorted(set(raw_config.keys()).difference(allowed_keys))
    if unknown:
        raise ScriptError(
            exit_code=ExitCode.config_error,
            title="Config file contains unknown keys",
            explanation="Unexpected keys make it unclear which settings the script should apply.",
            solution=f"Remove unknown keys from the JSON config. Unknown keys: {', '.join(unknown)}",
            help_text=f"Allowed keys: {', '.join(sorted(allowed_keys))}",
        )

    csv_path = Path(args.csv)

    out_dir_value = args.out_dir if args.out_dir is not None else raw_config.get("out_dir", ".")
    out_dir = out_dir_value if isinstance(out_dir_value, Path) else Path(str(out_dir_value))

    max_cov_value = args.max_coverage if args.max_coverage is not None else raw_config.get("max_coverage", 50.0)
    try:
        max_cov = float(max_cov_value)
    except (TypeError, ValueError) as ex:
        raise ScriptError(
            exit_code=ExitCode.config_error,
            title="Invalid max_coverage value",
            explanation="max_coverage must be a number representing an exclusive upper bound for coverage percentage.",
            solution="Set max_coverage to a number (e.g. 50) either in the JSON config or via --max-coverage.",
            help_text=str(ex),
        ) from ex

    if not (0.0 < max_cov <= 100.0):
        raise ScriptError(
            exit_code=ExitCode.validation_error,
            title="Invalid --max-coverage value",
            explanation="Coverage is expressed as a percentage, so the threshold must be within (0, 100].",
            solution="Use a value like 50 (meaning: include rows with Coverage < 50).",
        )

    assembly_value = args.assembly if args.assembly is not None else raw_config.get(
        "assembly", "Eneve.eBase.DataMigrator"
    )
    assembly = str(assembly_value)
    if not assembly.strip():
        raise ScriptError(
            exit_code=ExitCode.validation_error,
            title="Invalid assembly name",
            explanation="Assembly name cannot be empty.",
            solution="Provide a non-empty value via --assembly or config 'assembly'.",
        )

    actionable_value = (
        args.actionable_filter
        if args.actionable_filter is not None
        else raw_config.get("actionable_filter", True)
    )
    if not isinstance(actionable_value, bool):
        raise ScriptError(
            exit_code=ExitCode.config_error,
            title="Invalid actionable_filter value",
            explanation="actionable_filter must be a boolean.",
            solution="Set actionable_filter to true/false in the JSON config (or use --actionable-filter/--no-actionable-filter).",
        )
    actionable_filter = bool(actionable_value)

    preview_value = args.preview_limit if args.preview_limit is not None else raw_config.get("preview_limit", 50)
    try:
        preview_limit = int(preview_value)
    except (TypeError, ValueError) as ex:
        raise ScriptError(
            exit_code=ExitCode.config_error,
            title="Invalid preview_limit value",
            explanation="preview_limit must be an integer.",
            solution="Set preview_limit to an integer (e.g. 50) in the JSON config or via --preview-limit.",
            help_text=str(ex),
        ) from ex
    if preview_limit < 0:
        raise ScriptError(
            exit_code=ExitCode.validation_error,
            title="Invalid preview_limit value",
            explanation="preview_limit must be >= 0.",
            solution="Set preview_limit to 0 to disable previews, or a positive integer to cap output.",
        )

    if not csv_path.exists():
        raise ScriptError(
            exit_code=ExitCode.validation_error,
            title="Input CSV file does not exist",
            explanation="The file path provided via --csv was not found.",
            solution="Provide a valid path to crap-scores.csv via --csv.",
            location=str(csv_path),
        )

    return csv_path, out_dir, max_cov, assembly, actionable_filter, preview_limit


def main() -> int:
    args = parse_args()
    logger = setup_logging(verbose=bool(args.verbose))

    try:
        raw_config: dict[str, Any] = {}
        if args.config_file is not None:
            raw_config = _load_json_config(Path(args.config_file))

        csv_path, out_dir, max_cov, assembly, actionable_filter, preview_limit = _coalesce_config(raw_config, args)

        rows = parse_rows(csv_path)
        below = sort_for_triage(below_coverage(rows, max_cov))

        below_actionable = [r for r in below if is_actionable(r)] if actionable_filter else list(below)
        below_assembly = [r for r in below_actionable if r.assembly == assembly]

        max_label = str(int(max_cov)) if float(max_cov).is_integer() else str(max_cov).replace(".", "_")

        all_actionable_path = out_dir / f"coverage-below-{max_label}-all-actionable.csv"
        assembly_path = out_dir / f"coverage-below-{max_label}-{assembly}.csv"
        assembly_actionable_path = out_dir / f"coverage-below-{max_label}-{assembly}-actionable.csv"

        write_csv(all_actionable_path, below_actionable)
        write_csv(assembly_path, [r for r in below if r.assembly == assembly])
        write_csv(assembly_actionable_path, below_assembly)

        if preview_limit > 0:
            render_console_preview(
                logger, f"Coverage < {max_cov:g}% ({assembly}) - actionable", below_assembly, limit=preview_limit
            )
            render_console_preview(
                logger, f"Coverage < {max_cov:g}% (all assemblies) - actionable", below_actionable, limit=preview_limit
            )

        logger.info("")
        logger.info("Wrote:")
        logger.info("- %s", assembly_actionable_path)
        logger.info("- %s", assembly_path)
        logger.info("- %s", all_actionable_path)
        return int(ExitCode.success)

    except ScriptError as ex:
        diagnostic = ex.format_diagnostic()
        emit_azure_pipeline_error(ex.title)
        logger.error(diagnostic)
        return int(ex.exit_code)
    except Exception as ex:
        emit_azure_pipeline_error(str(ex))
        logger.error(
            "ERROR: Unhandled exception\n\nExplanation: The script failed unexpectedly.\n\nSolution: Re-run with --verbose and inspect the error details.\n"
        )
        logger.debug("Stack trace:", exc_info=True)
        return int(ExitCode.runtime_error)


if __name__ == "__main__":
    raise SystemExit(main())


