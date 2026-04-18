---
name: prs
description: "Use when the user asks about pull requests, code reviews, or wants an overview of PR activity across repos. Shows authored PRs, review requests, and CI status."
argument-hint: "[mine|review|repo-name] [--personal]"
---

# PRs

Unified pull request overview across all GitHub repos.

## Tools

| Tool | Purpose |
|------|---------|
| `mcp__github__list_pull_requests` | List PRs for a repo |
| `mcp__github__get_pull_request` | Get PR details |
| `mcp__github__get_pull_request_status` | Get CI/check status |
| `mcp__github__get_pull_request_reviews` | Get review status |
| `mcp__github__get_pull_request_comments` | Get review comments |
| `mcp__github__get_pull_request_files` | Get changed files |

## Repos to Check

**Default: Work repos only (<FLEET_ORG> org):**
dbt, huntress, foxxed, gokustats-back-end, milo, artemis-stablecoins-v2, artemis-python-tools, narrative

**With `--personal` flag, also check (chrisrogers37):**


Only check personal repos when `--personal` is explicitly passed. This avoids GitHub API rate limits.

## Operations

### 1. Overview (default)

Check for PRs authored by `chrisrogers37` and PRs requesting review across all repos. Run repo checks in parallel using multiple tool calls.

For each repo, call:
```
mcp__github__list_pull_requests
owner: "<FLEET_ORG>" (or "chrisrogers37" for personal)
repo: "<repo-name>"
state: "open"
```

Then categorize results:

**Needs your action:**
- PRs with changes requested on your authored PRs
- PRs where you're requested as reviewer
- PRs with failing CI

**Waiting on others:**
- Your PRs awaiting review
- Your PRs with CI running

**Recently merged:**
- Your PRs merged in last 24h

### 2. My PRs

Filter to only PRs authored by chrisrogers37:
```
mcp__github__list_pull_requests
owner: "<FLEET_ORG>"
repo: "<repo>"
state: "open"
```
Then filter results where author is chrisrogers37.

### 3. Review Requests

PRs where review is requested from chrisrogers37.

### 4. Specific Repo

When user says "/prs huntress" — check only that repo:
```
mcp__github__list_pull_requests
owner: "<FLEET_ORG>"
repo: "huntress"
state: "open"
```

### 5. PR Details

When user asks about a specific PR number:
```
mcp__github__get_pull_request
mcp__github__get_pull_request_status
mcp__github__get_pull_request_reviews
```
Run all three in parallel, then summarize.

## Output Formatting

When sending results via Telegram, use `format: "markdownv2"`. See [_telegram-formatting.md](../_telegram-formatting.md) for formatting rules.

```
PRS OVERVIEW

Needs your action:
- huntress #267 — changes requested by @reviewer
- dbt #3592 — CI failing (test_enrichment)
- foxxed #187 — review requested

Waiting on others:
- huntress #269 — awaiting review (opened 2h ago)

Merged today:
- huntress #266 — sqlparse fix (merged 4h ago)

No open PRs: claudefather, milo, narrative, gokustats-back-end
```

## Instructions

1. For **overview**: check all repos in parallel, group results by action needed
2. For **specific repo**: show all open PRs with status
3. Skip repos with no open PRs — just list them at the bottom
4. Always show CI status (passing/failing/pending) for open PRs
5. Prioritize PRs needing action at the top
6. When checking work repos, owner is "<FLEET_ORG>". For personal repos, owner is "chrisrogers37"

$ARGUMENTS
