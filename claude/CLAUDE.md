# Global Claude Code Guidelines

## Git

- Branch names must use the prefix `ilopezro/` (e.g. `ilopezro/fix-login-bug`)
- Do not push to remote unless explicitly asked

## Pull requests

When opening a PR, always open it in draft mode. The PR title must follow the conventional commit format (e.g. `feat: add login flow`, `fix: handle null user`). Before creating it, ask if there is a ticket number — if not, omit the Ticket section. Check for a PR template in the repo (look for common variations: `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/PULL_REQUEST_TEMPLATE/*.md`, `pull_request_template.md`, `PULL_REQUEST_TEMPLATE.md`) and use it. If none exists, use this structure:

```markdown
## Summary

### Ticket

<!-- Add the ID of your ClickUp ticket(s) that this PR addresses (ex: CU-2jrdk39) -->

### Description

<!-- Give a description of what this pull request does -->

### How to Test/Intended Behavior

<!-- Include instructions on how to test this work, if applicable -->
```

Keep the PR description current: after every commit or chunk of work pushed to a branch with an open PR, update the description so it accurately reflects the work as it stands — especially the Description and How to Test/Intended Behavior sections. Don't let it drift from the actual diff.

## Code style

- Only add comments where the logic isn't self-evident — avoid restating what the code already says
