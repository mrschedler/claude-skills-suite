---
name: github-sync
description: Commits and pushes changes to GitHub. Invoke explicitly with /github-sync or when user says "commit", "push", or "sync to GitHub".
argument-hint: [commit message, --amend to amend last commit, --branch <name> to push to a specific branch]
---

# GitHub Sync

Commit and push all changes in the current working tree to GitHub. Handle branching when needed. Leave the working tree clean.

## Instructions

1. **Assess the working tree.** Run `git status` to identify staged, unstaged, and untracked files. If the tree is already clean, report that and exit.

2. **Determine the commit message.**
   - If the user provided one, use it exactly.
   - If invoked by another skill (e.g., meta-clear), derive a message from the work context: what was built, fixed, or changed. Keep it under 72 characters for the subject line.
   - If neither applies, summarize the diff into a conventional-commit-style message (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`).

3. **Stage changes.** Run `git add -A` to stage everything. If the user specified particular files, stage only those.

4. **Review the diff.** Run `git diff --cached --stat` and show the summary to the user. If the diff is large (>20 files or >500 lines), call out the scope and confirm before committing — surprises in large commits cause pain later.

5. **Commit.** Run `git commit -m "<message>"`. If `--amend` was passed, use `git commit --amend --no-edit` (or with the new message if provided).

6. **Handle branches.**
   - If `--branch <name>` was passed, check out or create that branch before committing.
   - If the current branch has no upstream, set it: `git push -u origin <branch>`.
   - If on a feature branch and the user asks to merge, do not merge automatically — recommend they open a PR or confirm the merge target.

7. **Push.** Run `git push`. If the push is rejected (non-fast-forward), report the conflict and ask the user how to proceed (rebase, force-push, or pull first). Do not force-push without explicit confirmation.

8. **Verify.** Run `git status` one final time. The working tree should be clean. Report the commit hash, branch, and remote.

9. **Homelab Tools memory sync (MANDATORY).** After a successful push, update Qdrant so home Claude stays current. Per cross-cutting rule 7:
   - **Search first**: Query memory for this project name + `github-sync` tag to find the last known state.
   - **Store the delta**: Include commit hash, branch, files changed summary, and commit message. If a recent entry exists (<24h), update it instead of creating a new one.
   - Use `mcp__claude_ai_Homelab_Tools__memory_call` with `tool: 'store_memory'`. Tags: `github-sync`, `commit-log`, `{project-name}`.

## Examples

```
User: commit and push my changes
```
Assess working tree, generate a commit message from the diff, stage, commit, push, verify clean tree.

```
User: /github-sync fix: resolve null pointer in auth middleware
```
Use the provided message verbatim. Stage all changes, commit with that message, push.

```
User: push this to a new branch called feature/ws-auth
```
Create and check out `feature/ws-auth`, stage, commit, push with `-u origin feature/ws-auth`.

```
[Invoked by meta-clear]
```
Derive commit message from the session's work context. Stage, commit, push. Return control to meta-clear after confirming the tree is clean.

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
