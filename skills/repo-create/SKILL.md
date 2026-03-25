---
name: repo-create
description: Creates or connects a GitHub repo for the current project. Use when no remote origin exists, or to change repo visibility. Asks before acting.
---

# repo-create

Set up a GitHub repository for the project. This skill handles three scenarios:
the user has no repo yet, the user has an existing repo to connect, or the user
wants a new repo created. It never assumes — it asks.

## When to use

- User says "create a repo", "init git", "push to GitHub."
- A scaffolded project has no `.git/` directory or no remote origin.
- User wants to change repo visibility or reconnect to a different remote.

## Inputs

| Input | Source | Required |
|---|---|---|
| Project root path | cwd or user prompt | Yes |
| Repo name | User prompt (ask if not given) | Yes |
| Visibility | User prompt (ask every time) | Yes |
| Existing repo URL | User prompt (if connecting) | No |

## Instructions

1. **Ask before acting.** Start with these questions — do not skip any:
   - "Do you already have a GitHub repo for this project?"
   - If yes: "What's the repo URL?" Then skip to step 5.
   - If no: "What should the repo be named?"
   - **Always ask visibility**: "Public or private?" Do not default. The user
     decides every time because the wrong visibility leaks code or blocks
     collaboration.

2. **Check prerequisites.** Verify `git` is installed and `gh` CLI is
   authenticated (`gh auth status`). If `gh` is not available, fall back to
   `git` + GitHub API via the MCP GitHub tools. Tell the user which path you're
   taking.

3. **Initialize local git** (if `.git/` doesn't exist):
   ```bash
   cd <project-root>
   git init
   ```

4. **Create the GitHub repo.** Use the `gh` CLI:
   ```bash
   gh repo create <repo-name> --<visibility> --source=. --remote=origin
   ```
   If `gh` is unavailable, use the GitHub MCP `create_repository` tool, then
   add the remote manually:
   ```bash
   git remote add origin <repo-url>
   ```

5. **Connect to existing repo** (if user provided a URL):
   ```bash
   git remote add origin <repo-url>
   git fetch origin
   ```
   If a remote named `origin` already exists and points somewhere else, ask
   before overwriting. Silently clobbering a remote loses work — always confirm.

6. **Ensure .gitignore exists.** If `/project-organize` already ran, it will be
   there. If not, create a sensible default (node_modules, .env, .DS_Store,
   artifacts/, __pycache__). Never commit secrets — the .gitignore is your first
   line of defense.

7. **Initial commit and push:**
   ```bash
   git add .
   git commit -m "chore: initial project scaffold"
   git branch -M main
   git push -u origin main
   ```
   If there's already commit history, skip the initial commit — just push.

8. **Confirm.** Print the repo URL and confirm the push succeeded.

## Exit condition

- GitHub repo exists (created or pre-existing).
- Local `.git/` is initialized with `origin` remote pointing to the repo.
- At least one commit is pushed to `main`.
- User has seen the repo URL.

## Examples

```
User: "Create a repo for this project"
Action: Ask repo name and visibility. Create repo, init git, push initial
        commit. Print URL.
```

```
User: "I already have a repo at github.com/user/my-project"
Action: Add remote origin, fetch, confirm connection. Do not create a new repo.
```

```
User: "Set up git, call it dash-ui, make it private"
Action: Create private repo named dash-ui, init, push. No need to ask
        visibility — user already specified.
```

```
User: "Push to GitHub"
Action: Check if git is initialized and remote exists. If not, ask the
        prerequisite questions. If yes, just push.
```

## Cross-cutting

Before completing, read and follow `../references/cross-cutting-rules.md`.
