#!/usr/bin/env python3
"""
PROGRESS.md Validator for Ralph Workflow

Validates that PROGRESS.md follows the canonical template structure
to prevent documentation drift across agent sessions.

Usage:
    python validate_progress.py [path/to/PROGRESS.md]

If no path provided, looks for PROGRESS.md in current directory
or docs/PROGRESS.md.

Exit codes:
    0 - Valid
    1 - Validation errors found
    2 - File not found

Anti-drift safeguards by Claude & Matt Schedler (2026)
"""

import sys
import re
import io
from pathlib import Path
from typing import List, Tuple

# Fix Windows console encoding
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# Required fields in each story completion entry
REQUIRED_FIELDS = [
    "**What**:",
    "**Files Changed**:",
    "**Gotcha**:",
    "**Verified**:",
    "**Next**:",
]

# Pattern for story entry header: ### [YYYY-MM-DD] Story X.Y: Title
STORY_HEADER_PATTERN = r"^### \[\d{4}-\d{2}-\d{2}\] Story \d+\.\d+: .+"

# Pattern for TL;DR table fields
TLDR_REQUIRED = [
    "Current Story",
    "Last Completed",
]


def find_progress_file() -> Path:
    """Find PROGRESS.md in common locations."""
    candidates = [
        Path("PROGRESS.md"),
        Path("docs/PROGRESS.md"),
        Path("progress.md"),
        Path("docs/progress.md"),
    ]

    for candidate in candidates:
        if candidate.exists():
            return candidate

    return None


def extract_story_entries(content: str) -> List[Tuple[str, str, int]]:
    """Extract all story completion entries from PROGRESS.md.

    Returns list of (header, content, line_number) tuples.
    """
    lines = content.split("\n")
    entries = []
    current_entry = None
    current_content = []
    current_line = 0

    for i, line in enumerate(lines, 1):
        if re.match(STORY_HEADER_PATTERN, line):
            # Save previous entry if exists
            if current_entry:
                entries.append((current_entry, "\n".join(current_content), current_line))
            # Start new entry
            current_entry = line
            current_content = [line]
            current_line = i
        elif current_entry:
            # Check if we've hit the next section or entry
            if line.startswith("## ") or line.startswith("---"):
                entries.append((current_entry, "\n".join(current_content), current_line))
                current_entry = None
                current_content = []
            else:
                current_content.append(line)

    # Don't forget the last entry
    if current_entry:
        entries.append((current_entry, "\n".join(current_content), current_line))

    return entries


def validate_entry(header: str, content: str, line_num: int) -> List[str]:
    """Validate a single story entry has all required fields."""
    errors = []

    for field in REQUIRED_FIELDS:
        if field not in content:
            errors.append(f"Line {line_num}: Entry '{header[:50]}...' missing required field: {field}")

    # Check for truly empty fields
    # A field is empty if it has nothing meaningful after the colon on the same line
    # AND the next line is either another field, a header, or empty
    lines = content.split('\n')
    for i, line in enumerate(lines):
        for field in REQUIRED_FIELDS:
            if field in line:
                # Get content after the field marker
                after_field = line.split(field, 1)[1].strip() if field in line else ""

                # If nothing after field on same line, check if next line has content
                if not after_field:
                    # Check next line
                    if i + 1 < len(lines):
                        next_line = lines[i + 1].strip()
                        # If next line is empty, another field, or a header, this field is empty
                        if (not next_line or
                                next_line.startswith("**") or
                                next_line.startswith("#") or
                                next_line.startswith("-")):
                            # Exception: Files Changed is followed by bullet points
                            if field == "**Files Changed**:" and next_line.startswith("-"):
                                continue
                            errors.append(f"Line {line_num}: Entry '{header[:50]}...' has empty field: {field}")
                    else:
                        errors.append(f"Line {line_num}: Entry '{header[:50]}...' has empty field: {field}")

    return errors


def validate_tldr(content: str) -> List[str]:
    """Validate TL;DR section has required fields."""
    errors = []

    # Find TL;DR section
    tldr_match = re.search(r"## TL;DR.*?(?=\n## |\n---|\Z)", content, re.DOTALL)
    if not tldr_match:
        errors.append("Missing '## TL;DR' section")
        return errors

    tldr_content = tldr_match.group()

    for field in TLDR_REQUIRED:
        if field not in tldr_content:
            errors.append(f"TL;DR section missing required field: {field}")

    return errors


def validate_canonical_template(content: str) -> List[str]:
    """Validate that canonical template exists at bottom."""
    errors = []

    if "CANONICAL TEMPLATE" not in content:
        errors.append("Missing CANONICAL TEMPLATE section at bottom of file")

    if "DO NOT copy from the last entry" not in content:
        errors.append("Missing anti-drift warning in CANONICAL TEMPLATE section")

    return errors


def check_for_drift(entries: List[Tuple[str, str, int]]) -> List[str]:
    """Check if recent entries have different field counts (indicating drift)."""
    warnings = []

    if len(entries) < 2:
        return warnings

    # Count fields in each entry
    field_counts = []
    for header, content, line_num in entries[:5]:  # Check last 5 entries
        count = sum(1 for field in REQUIRED_FIELDS if field in content)
        field_counts.append((header, count, line_num))

    # Check for inconsistency
    counts = [c[1] for c in field_counts]
    if len(set(counts)) > 1:
        warnings.append("WARNING: Inconsistent field counts detected across recent entries (possible drift):")
        for header, count, line_num in field_counts:
            warnings.append(f"  Line {line_num}: {count}/{len(REQUIRED_FIELDS)} fields - {header[:40]}...")

    return warnings


def validate_progress_file(filepath: Path) -> Tuple[List[str], List[str]]:
    """Validate PROGRESS.md file.

    Returns (errors, warnings) tuple.
    """
    errors = []
    warnings = []

    content = filepath.read_text(encoding="utf-8")

    # Validate TL;DR section
    errors.extend(validate_tldr(content))

    # Validate canonical template exists
    errors.extend(validate_canonical_template(content))

    # Extract and validate story entries
    entries = extract_story_entries(content)

    if not entries:
        warnings.append("No story completion entries found (this may be OK for new projects)")
    else:
        for header, entry_content, line_num in entries:
            errors.extend(validate_entry(header, entry_content, line_num))

        # Check for drift
        warnings.extend(check_for_drift(entries))

    return errors, warnings


def main():
    # Determine file path
    if len(sys.argv) > 1:
        filepath = Path(sys.argv[1])
    else:
        filepath = find_progress_file()

    if filepath is None or not filepath.exists():
        print("ERROR: PROGRESS.md not found")
        print("Looked in: PROGRESS.md, docs/PROGRESS.md")
        print("Usage: python validate_progress.py [path/to/PROGRESS.md]")
        sys.exit(2)

    print(f"Validating: {filepath}")
    print("-" * 50)

    errors, warnings = validate_progress_file(filepath)

    # Print warnings
    if warnings:
        print("\nWARNINGS:")
        for warning in warnings:
            print(f"  {warning}")

    # Print errors
    if errors:
        print("\nERRORS:")
        for error in errors:
            print(f"  {error}")
        print(f"\n{len(errors)} error(s) found. Fix before marking story complete.")
        sys.exit(1)
    else:
        print("\nVALIDATION PASSED")
        if warnings:
            print(f"({len(warnings)} warning(s) - review recommended)")
        sys.exit(0)


if __name__ == "__main__":
    main()
