---
name: spec-write
description: Electrical/hardware spec house rules. Use when writing, editing, or reviewing hardware specs, connection tables, or spec emails to board designers.
---

# Spec Write

Applies Matt's house rules for electrical/hardware specifications. These rules
exist because agent-written specs drift into propositional prose — hedged
warnings, inline justification, options instead of decisions, connections
buried in sentences. The rules were established 2026-07-20 during the G3
Enterprise carrier-spec rework with a design house, and caught real defects
(a backwards-drawn buffer, unspecified unused-gate tie-offs, body-vs-BOM part
disagreements). A spec is a build print: the designer draws exactly what it
says, so it must say exactly what to draw.

## Inputs

- The spec file being written or edited (markdown; possibly a paired .docx)
- Component datasheets for any pin numbers cited (PDFs, local or fetched)
- The project's Rationale document, if one exists (destination for "why")
- Project GROUNDING.md, if present

## Outputs

- Spec text conforming to the rules below
- A compliance report when reviewing an existing spec (rule-by-rule findings)

## Instructions

### Phase 1: Orient

1. Read the project's GROUNDING.md if present.
2. Locate the spec and its companion Rationale document. If no Rationale doc
   exists and why-content needs a home, note that in the output — do not
   invent a new file without the user confirming.
3. Search memory for prior spec-writing feedback in this project
   (`memory_call > search "spec writing"` — graceful skip if unavailable).

### Phase 2: Apply the rules

Write (or rewrite) to these nine rules:

1. **Audience.** Every sentence is for the board designer who draws the
   schematic. If a sentence does not change what they draw, delete it or move
   it to the Rationale. Customer notes, deployment notes, firmware notes, and
   notes-to-future-self are noise.
2. **Facts, not arguments.** A part being in the spec IS the requirement —
   never "required, do not remove." State circuits as fixed facts: "the
   resistor is not in series with this trace," never "the resistor is never in
   series between X and Y" (reads as conditional). No hedging, no "should."
3. **Why lives elsewhere.** Reasoning, trade-offs, and accepted risks go in
   the Rationale, linked by short pointers ("why: Rationale §7"). One inline
   why-clause is allowed only when it prevents a review error.
4. **Connection table per subsystem.** Three columns: Pin | Signal | Connects
   to. Cells are component-first: `CM4 GPIO9, MISO (shared net)` — destination
   component and pin lead, net name after the comma, notes after a semicolon.
   Never bury a connection in a sentence. Unused pins get rows: explicitly NC
   or tied off. Pin numbers come from the datasheet, never from memory.
5. **Both ends and direction of every signal.** Each net names its source,
   all its loads, and which way data flows. A line driving two loads lists
   both.
6. **Decide, don't offer options.** No levers, no "default X or Y." Pick the
   part number. Body text and BOM row must agree. "verify" in the BOM stock
   column is the only permitted uncertainty.
7. **Standalone sections.** One section per subsystem, readable without the
   others. Bullets over paragraphs, one topic per bullet, nested bullets for
   enumerations. Any checklist states who it is for. Sweep every
   cross-reference after a renumber.
8. **Verified numbers only.** Pins from datasheets, memory sizes from firmware
   source, power from measurements. If a number cannot be cited, do not write
   it.
9. **Mechanics.** No em/en dashes (use " - "). No markdown artifacts
   (backticks) in Word exports. Word tables get explicit column widths
   (narrow pin/signal, wide connects-to) and repeated header rows.

### Phase 3: Verify

Walk the finished text against the rules as a checklist. For a review of an
existing spec, report findings per rule with location and a concrete fix.
Confirm: every table cell component-first; every net has both ends; every
cited number has a source; body and BOM agree on every part.

### Phase 4: Designer communications (when drafting emails)

Board designers work in drawings, not prose. Many have never worked from an
all-text spec. Communicate in their native format:

- **Lead with a picture when one exists.** Attach the reference schematic
  figure (crop it from the datasheet PDF), a redlined markup of their own
  drawing, or a connection table. Prose describes a circuit only when no
  drawing of it exists anywhere.
- **One connection per sentence, plain words.** "The switch enable pin
  connects to CM4 pin 75." Never compressed notation ("EN = pin 75 w/ 12K
  pull-up") — shorthand that is normal in-repo is noise to a whiteboard
  thinker.
- Spell out symbols: "Section 6," not "§6."
- Bullets; the issue first; minimal filler.
- Each bullet carries a spec section + page pointer.
- State what to change — never describe what the recipient's draft shows.
- One line of intent is allowed when it prevents a wrong simplification
  ("the switch exists so the CM4 can power-cycle a hung card").

### Phase 5: Persist

If the session produced new spec-writing feedback from the user, store it
(`memory_call > store`, and update this skill if the rule is general).
Agents without MCP access: surface the feedback in output for capture.

## Examples

```
User: add a section to the spec for the CAN transceiver.
→ Phase 1-3: write the section with a connection table, decided part number,
  why-pointers to the Rationale. Report any datasheet pins that need verifying.
```

```
User: review this power section before it goes to the layout house.
→ Phase 3 as a lens: rule-by-rule findings (buried connections, undecided
  options, uncited numbers), each with a fix.
```

```
User: draft the feedback email to the designer about the schematic.
→ Phase 4 rules: bullets, issue first, section+page pointers, changes only.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
