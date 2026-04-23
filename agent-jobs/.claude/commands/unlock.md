---
description: Force-release a stale lock in CURRENT.md. Use when an agent crashed mid-cycle and TTL hasn't expired yet.
allowed-tools: Read, Edit, Bash
---

Force-release the lock in `.workflow/CURRENT.md`.

1. Read `.workflow/CURRENT.md`.
2. Show current lock holder and expiry.
3. Ask user to confirm: "Release lock held by {owner}? Reason?"
4. On confirm: edit frontmatter to clear `owner`, `lock_acquired_at`, `lock_expires_at`. Append a line to a `.workflow/LOCK_HISTORY.md` file (create if missing) recording the forced release with timestamp + reason.
5. Commit:
   ```
   chore(workflow): force-released stale lock — {reason}
   ```
6. Suggest: "Run /tick to resume."
