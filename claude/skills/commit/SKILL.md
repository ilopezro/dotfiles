---
name: commit
description: Generates a conventional commit message for staged changes. Use when the user asks to write a commit message or create a commit.
allowed-tools: Bash, Read, Grep
---

Generate a conventional commit message for the staged changes only. Explain accurately and succinctly. Use imperative mood. Subject line: max 50 chars, captures WHAT at high level. Body: explains WHY and HOW, wrapped at 72 chars with hard breaks. Use simple, direct language. Output ONLY the commit message text.

## Instructions

1. Run `git diff --cached` to see the staged changes
2. Analyze what changed and why
3. Write a commit message following this format:

**Subject line (max 50 chars):**
- Start with conventional commit type if applicable (feat, fix, refactor, docs, etc.)
- Use imperative mood ("Add" not "Added" or "Adds")
- Capture WHAT changed at a high level
- No period at the end

**Body (wrapped at 72 chars):**
- Blank line after subject
- Explain WHY the change was made
- Explain HOW it works if not obvious
- Use hard line breaks at 72 characters
- Can have multiple paragraphs if needed

**Co-author trailer:**
- End every message with a `Co-Authored-By` trailer, after a blank line
- Credit the model actually running at the time — never a hardcoded name
- Format: `Co-Authored-By: Claude <model name> <noreply@anthropic.com>`

Output ONLY the final commit message text, nothing else.
