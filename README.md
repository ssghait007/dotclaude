# dotclaude

My Claude Code configuration — statusline, plugins, hooks, and settings.

## Plugins

| Plugin | What it does |
|--------|-------------|
| **claude-mem** | Persistent cross-session memory — stores observations, decisions, and learnings in a searchable database so future conversations can recall past work without re-investigating |
| **superpowers** | Adds structured workflows (brainstorming, TDD, debugging, planning, code review) as skills — enforces disciplined processes instead of ad-hoc coding |
| **context-mode** | Routes large tool outputs through a sandbox instead of flooding your context window — runs commands/analysis externally and returns only summaries, saving ~90% of token budget |
| **frontend-design** | Generates polished, production-grade UI components — avoids generic AI aesthetics by following design principles (project-scoped) |

## PreToolUse Hooks

| Hook | Trigger | Action | Why |
|------|---------|--------|-----|
| **check-weekly-limit** | Every Bash/prompt (throttled 5min) | **Block** at 100% API usage | Prevents burning extra credits when weekly limit is exhausted |
| **enforce-git-push-syntax** | `git push` without `origin` | **Deny** | Forces explicit `git push origin <branch>` to avoid pushing to wrong remote/branch |
| **enforce-bunx** | `npx` or `npm` commands | **Deny** | Project uses Bun — redirects to `bunx`/`bun` equivalents |
| **guard-rm-rf** | `rm -rf` | **Ask** | Recursive force-delete is irreversible — requires confirmation |
| **guard-terraform** | `terraform destroy` | **Deny** | Blocks destroy entirely; `apply -auto-approve` and `state rm` require confirmation |
| **guard-aws** | `aws` without `--profile` | **Deny** | Prevents accidentally using wrong AWS account credentials |
| **guard-aws-profile** | `aws s3 rb`, `ec2 terminate`, `iam create-access-key` | **Ask** | Destructive/sensitive AWS ops need confirmation even with correct profile |
| **guard-gcp** | `gcloud projects delete`, `gsutil rm -r` | **Ask** | Project deletion and recursive bucket wipes are irreversible |
| **guard-kubectl** | `kubectl delete/drain/exec/edit` | **Ask** | Cluster mutations can cause outages — requires confirmation |
| **guard-tsh** | Dangerous commands tunneled via `tsh ssh` | **Ask** | Catches destructive ops (kubectl delete, psql, rm -rf) hidden inside Teleport tunnels |

**Hook pattern:** `deny` = never allowed (Claude must use the correct alternative), `ask` = allowed but needs human confirmation.

## Other Event Hooks

| Event | What it does |
|-------|-------------|
| **Stop** | Plays `done-or-stop.wav` when Claude finishes |
| **Notification** | Plays `needs-input.wav` when Claude needs input |
| **SubagentStop** | Plays `subagent-stop.wav` when a subagent completes |

## Statusline

Custom 5-line status bar showing:
1. Model name, context progress bar, % used, token counts (in/out)
2. Folder name, repo:branch, diff stats (+/-)
3. 5-hour usage bar + % + reset time
4. 7-day weekly usage bar + % + reset time
5. 7-day Sonnet-specific usage bar + % + reset time

## Setup

```bash
# Clone
git clone git@github.com:ssghait007/dotclaude.git

# Copy to ~/.claude/
cp statusline-command.sh ~/.claude/
cp settings.json ~/.claude/
cp hooks/*.sh ~/.claude/hooks/
```
