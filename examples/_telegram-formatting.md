# Telegram Formatting Reference

Telegram uses a limited subset of Markdown. Not all formatting renders correctly.

## What Works

- **Bold**: `*bold*` or `**bold**`
- _Italic_: `_italic_`
- `Code`: backtick inline code
- ```Code blocks```: triple backtick blocks
- [Links](url): `[text](url)`
- ~~Strikethrough~~: `~~text~~`

## What Doesn't Work

- # Headers — rendered as plain text
- Tables — use code blocks instead
- Bullet lists — work but no nesting
- Images — can't embed inline, send as separate photos

## Best Practices

- Keep messages concise — this is mobile chat
- Use code blocks for structured data (orders, status reports)
- Use bold for section headers instead of markdown headers
- One message per topic — don't wall-of-text
- Include links to PRs, issues, dashboards when referencing them
- Use line breaks for readability, but don't over-space
