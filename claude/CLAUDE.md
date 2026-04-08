# Global Claude Code Guidelines

## Git

- Branch names must use the prefix `ilopezro/` (e.g. `ilopezro/fix-login-bug`)
- Do not push to remote unless explicitly asked

## Pull requests

When opening a PR, always open it in draft mode. Check for a `.github/pull_request_template.md` in the repo and use it. If none exists, use this structure:

```markdown
## Summary

### Ticket

<!-- Add the ID of your ClickUp ticket(s) that this PR addresses (ex: CU-2jrdk39) -->

### Description

<!-- Give a description of what this pull request does -->

### How to Test/Intended Behavior

<!-- Include instructions on how to test this work, if applicable -->
```

## Code style

- Only add comments where the logic isn't self-evident — avoid restating what the code already says
