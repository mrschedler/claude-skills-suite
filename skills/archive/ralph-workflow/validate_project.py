#!/usr/bin/env python3
"""
Project Validation Script for Ralph Workflow

Comprehensive validation that checks:
1. PROGRESS.md structure (via validate_progress.py)
2. USER_STORIES.md consistency
3. Cross-file consistency (PROGRESS ↔ USER_STORIES ↔ README)
4. Story ordering and dependencies
5. Phase completion status

Triggers:
- Run at phase transitions (all X.* stories complete, starting (X+1).*)
- Run every 5 stories completed
- Run manually anytime

Usage:
    python validate_project.py [--phase-check] [--full]

Exit codes:
    0 - Valid
    1 - Validation errors found
    2 - File not found

Anti-drift safeguards by Claude & Matt Schedler (2026)
"""

import sys
import re
import os
from pathlib import Path
from typing import List, Tuple, Dict, Set, Optional
from collections import defaultdict

# Fix Windows console encoding
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except AttributeError:
        # Python < 3.7
        pass

# Import validate_progress if available
try:
    from validate_progress import validate_progress_file, find_progress_file
    HAS_PROGRESS_VALIDATOR = True
except ImportError:
    HAS_PROGRESS_VALIDATOR = False


def find_user_stories_file() -> Optional[Path]:
    """Find USER_STORIES.md in common locations."""
    candidates = [
        Path("USER_STORIES.md"),
        Path("docs/USER_STORIES.md"),
        Path("prd.json"),
        Path("docs/prd.json"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


def find_readme_file() -> Optional[Path]:
    """Find README.md."""
    candidates = [Path("README.md"), Path("docs/README.md")]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


def extract_stories_from_user_stories(content: str) -> Dict[str, dict]:
    """
    Extract stories from USER_STORIES.md.

    Returns dict: story_id -> {title, completed, criteria_total, criteria_checked}
    """
    stories = {}

    # Pattern: ### Story X.Y: Title or ## Story X.Y: Title
    story_pattern = r"^#{2,3}\s+Story\s+(\d+\.\d+):\s*(.+?)(?:\s*[✅⏳🚧])?\s*$"

    lines = content.split('\n')
    current_story = None
    current_criteria_total = 0
    current_criteria_checked = 0
    in_acceptance = False

    for i, line in enumerate(lines):
        # Check for story header
        match = re.match(story_pattern, line)
        if match:
            # Save previous story
            if current_story:
                stories[current_story]['criteria_total'] = current_criteria_total
                stories[current_story]['criteria_checked'] = current_criteria_checked

            story_id = match.group(1)
            title = match.group(2).strip()
            completed = '✅' in line or 'Complete' in line

            # Also check for **Status**: Complete pattern
            for j in range(i+1, min(i+5, len(lines))):
                if '**Status**:' in lines[j] and 'Complete' in lines[j]:
                    completed = True
                    break

            stories[story_id] = {
                'title': title,
                'completed': completed,
                'criteria_total': 0,
                'criteria_checked': 0,
            }
            current_story = story_id
            current_criteria_total = 0
            current_criteria_checked = 0
            in_acceptance = False
            continue

        # Check for acceptance criteria section
        if current_story and ('Acceptance Criteria' in line or 'acceptance' in line.lower()):
            in_acceptance = True
            continue

        # Count criteria checkboxes
        if current_story and in_acceptance:
            if re.match(r'^\s*-\s*\[x\]', line, re.IGNORECASE):
                current_criteria_total += 1
                current_criteria_checked += 1
            elif re.match(r'^\s*-\s*\[\s*\]', line):
                current_criteria_total += 1

    # Don't forget last story
    if current_story:
        stories[current_story]['criteria_total'] = current_criteria_total
        stories[current_story]['criteria_checked'] = current_criteria_checked

    return stories


def extract_stories_from_progress(content: str) -> Set[str]:
    """Extract completed story IDs from PROGRESS.md completion log."""
    completed = set()

    # Pattern: ### [YYYY-MM-DD] Story X.Y: Title
    pattern = r"###\s+\[\d{4}-\d{2}-\d{2}\]\s+Story\s+(\d+\.\d+):"

    for match in re.finditer(pattern, content):
        completed.add(match.group(1))

    return completed


def extract_stories_from_readme(content: str) -> Set[str]:
    """Extract completed story IDs from README.md progress section."""
    completed = set()

    # Pattern: [x] **Story X.Y** or - [x] Story X.Y or ✅
    patterns = [
        r"\[x\].*Story\s+(\d+\.\d+)",
        r"Story\s+(\d+\.\d+).*✅",
        r"\*\*Story\s+(\d+\.\d+)\*\*.*✅",
    ]

    for pattern in patterns:
        for match in re.finditer(pattern, content, re.IGNORECASE):
            completed.add(match.group(1))

    return completed


def get_phase(story_id: str) -> int:
    """Extract phase number from story ID (e.g., '2.3' -> 2)."""
    return int(story_id.split('.')[0])


def validate_story_order(stories: Dict[str, dict]) -> Tuple[List[str], List[str]]:
    """
    Validate that stories are completed in order within phases.

    Returns (errors, warnings) - out-of-order is a warning, not error,
    since some projects use dependency-based ordering.
    """
    errors = []
    warnings = []

    # Group by phase
    phases = defaultdict(list)
    for story_id in stories:
        phase = get_phase(story_id)
        phases[phase].append(story_id)

    # Sort stories within each phase
    for phase in phases:
        phases[phase].sort(key=lambda x: float(x))

    # Check order within each phase
    for phase, story_ids in sorted(phases.items()):
        found_incomplete = False
        incomplete_id = None
        for story_id in story_ids:
            if stories[story_id]['completed']:
                if found_incomplete:
                    # Out-of-order is a warning, not error (dependency-based ordering is valid)
                    warnings.append(f"Story {story_id} completed before {incomplete_id} (out of numerical order)")
            else:
                if not found_incomplete:
                    incomplete_id = story_id
                found_incomplete = True

    return errors, warnings


def check_phase_completion(stories: Dict[str, dict]) -> Tuple[Dict[int, bool], int, Optional[int]]:
    """
    Check which phases are complete.

    Returns: (phase_status dict, current_phase, next_phase_if_transitioning)
    """
    phases = defaultdict(list)
    for story_id, info in stories.items():
        phase = get_phase(story_id)
        phases[phase].append((story_id, info['completed']))

    phase_status = {}
    for phase, story_list in phases.items():
        all_complete = all(completed for _, completed in story_list)
        phase_status[phase] = all_complete

    # Determine current phase (first phase with incomplete stories)
    current_phase = None
    for phase in sorted(phases.keys()):
        if not phase_status[phase]:
            current_phase = phase
            break

    if current_phase is None:
        current_phase = max(phases.keys()) if phases else 1

    # Check if transitioning (previous phase just completed)
    transitioning_to = None
    if current_phase > 1 and phase_status.get(current_phase - 1, False):
        # Check if we just completed the previous phase
        prev_phase_stories = [s for s, _ in phases[current_phase - 1]]
        curr_phase_stories = [s for s, c in phases[current_phase] if c]
        if prev_phase_stories and not curr_phase_stories:
            transitioning_to = current_phase

    return phase_status, current_phase, transitioning_to


def validate_cross_file_consistency(
    user_stories: Dict[str, dict],
    progress_completed: Set[str],
    readme_completed: Set[str]
) -> List[str]:
    """Check that all three files agree on completion status."""
    errors = []

    user_stories_completed = {sid for sid, info in user_stories.items() if info['completed']}

    # Check PROGRESS.md has entries for all completed stories
    for story_id in user_stories_completed:
        if story_id not in progress_completed:
            errors.append(f"Story {story_id} marked complete in USER_STORIES.md but missing from PROGRESS.md completion log")

    # Check README matches USER_STORIES
    for story_id in user_stories_completed:
        if story_id not in readme_completed:
            errors.append(f"Story {story_id} marked complete in USER_STORIES.md but not in README.md progress section")

    # Check for orphaned entries in PROGRESS.md
    for story_id in progress_completed:
        if story_id in user_stories and not user_stories[story_id]['completed']:
            errors.append(f"Story {story_id} has PROGRESS.md entry but not marked complete in USER_STORIES.md")

    return errors


def validate_criteria_completion(stories: Dict[str, dict]) -> List[str]:
    """Check that completed stories have all criteria checked."""
    errors = []

    for story_id, info in stories.items():
        if info['completed']:
            if info['criteria_total'] > 0 and info['criteria_checked'] < info['criteria_total']:
                errors.append(
                    f"Story {story_id} marked complete but only {info['criteria_checked']}/{info['criteria_total']} criteria checked"
                )

    return errors


def count_completed_stories(stories: Dict[str, dict]) -> int:
    """Count total completed stories."""
    return sum(1 for info in stories.values() if info['completed'])


def main():
    print("=" * 60)
    print("PROJECT VALIDATION - Ralph Workflow")
    print("=" * 60)

    errors = []
    warnings = []

    # 1. Find and validate PROGRESS.md
    print("\n[1/5] Validating PROGRESS.md structure...")
    if HAS_PROGRESS_VALIDATOR:
        progress_file = find_progress_file()
        if progress_file:
            prog_errors, prog_warnings = validate_progress_file(progress_file)
            errors.extend(prog_errors)
            warnings.extend(prog_warnings)
            print(f"      Found: {progress_file}")
            if not prog_errors:
                print("      ✓ Structure valid")
        else:
            errors.append("PROGRESS.md not found")
            print("      ✗ Not found")
    else:
        print("      ⚠ validate_progress.py not available, skipping")

    # 2. Find and parse USER_STORIES.md
    print("\n[2/5] Parsing USER_STORIES.md...")
    user_stories_file = find_user_stories_file()
    if not user_stories_file:
        errors.append("USER_STORIES.md or prd.json not found")
        print("      ✗ Not found")
        user_stories = {}
    else:
        print(f"      Found: {user_stories_file}")
        content = user_stories_file.read_text(encoding='utf-8')
        user_stories = extract_stories_from_user_stories(content)
        print(f"      ✓ Found {len(user_stories)} stories")

    # 3. Validate story order and criteria
    print("\n[3/5] Validating story completion...")
    if user_stories:
        order_errors, order_warnings = validate_story_order(user_stories)
        errors.extend(order_errors)
        warnings.extend(order_warnings)

        criteria_errors = validate_criteria_completion(user_stories)
        errors.extend(criteria_errors)

        completed_count = count_completed_stories(user_stories)
        print(f"      ✓ {completed_count}/{len(user_stories)} stories completed")

        if order_warnings:
            print(f"      ⚠ {len(order_warnings)} stories completed out of numerical order (may be OK if dependency-based)")

        if not order_errors and not criteria_errors:
            print("      ✓ Criteria completion valid")

    # 4. Cross-file consistency
    print("\n[4/5] Checking cross-file consistency...")
    progress_completed = set()
    readme_completed = set()

    progress_file = find_progress_file() if HAS_PROGRESS_VALIDATOR else None
    if not progress_file:
        for p in [Path("PROGRESS.md"), Path("docs/PROGRESS.md")]:
            if p.exists():
                progress_file = p
                break

    if progress_file and progress_file.exists():
        progress_completed = extract_stories_from_progress(
            progress_file.read_text(encoding='utf-8')
        )

    readme_file = find_readme_file()
    if readme_file:
        readme_completed = extract_stories_from_readme(
            readme_file.read_text(encoding='utf-8')
        )

    if user_stories:
        consistency_errors = validate_cross_file_consistency(
            user_stories, progress_completed, readme_completed
        )
        errors.extend(consistency_errors)

        if not consistency_errors:
            print("      ✓ All files consistent")
        else:
            print(f"      ✗ {len(consistency_errors)} inconsistencies found")

    # 5. Phase completion check
    print("\n[5/5] Checking phase status...")
    if user_stories:
        phase_status, current_phase, transitioning = check_phase_completion(user_stories)

        for phase, complete in sorted(phase_status.items()):
            status = "✓ Complete" if complete else "○ In Progress"
            print(f"      Phase {phase}: {status}")

        print(f"\n      Current Phase: {current_phase}")

        if transitioning:
            print(f"\n      *** PHASE TRANSITION DETECTED ***")
            print(f"      Phase {transitioning - 1} complete, starting Phase {transitioning}")
            print(f"      This validation run is MANDATORY before continuing.")

        # Check if we should recommend validation (every 5 stories)
        completed_count = count_completed_stories(user_stories)
        if completed_count > 0 and completed_count % 5 == 0:
            print(f"\n      *** MILESTONE: {completed_count} stories completed ***")
            print(f"      Validation checkpoint reached.")

    # Summary
    print("\n" + "=" * 60)
    if errors:
        print("VALIDATION FAILED")
        print("=" * 60)
        print("\nErrors:")
        for error in errors:
            print(f"  ✗ {error}")
        if warnings:
            print("\nWarnings:")
            for warning in warnings:
                print(f"  ⚠ {warning}")
        print(f"\n{len(errors)} error(s) found. Fix before continuing.")
        sys.exit(1)
    else:
        print("VALIDATION PASSED")
        print("=" * 60)
        if warnings:
            print("\nWarnings (review recommended):")
            for warning in warnings:
                print(f"  ⚠ {warning}")
        print("\n✓ Project state is consistent. Safe to continue.")
        sys.exit(0)


if __name__ == "__main__":
    main()
