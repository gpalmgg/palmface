# Plugins that go well with Palmface

Palmface doesn't install plugins. This is a short list of public ones to add yourself, all from
Anthropic's official marketplace, `claude-plugins-official`. Newer Claude Code versions list
that marketplace already. If yours doesn't, add it once:

```
/plugin marketplace add anthropics/claude-plugins-official
```

Then install by name, either inside Claude Code or from your shell:

```
/plugin install <name>@claude-plugins-official
claude plugin install <name>@claude-plugins-official
```

Restart Claude Code after installing. Plugin skills show up as `<plugin>:<skill>`, for example
`superpowers:brainstorming`, so they never clash with Palmface's `palmface-*` skills.

## Recommended with Palmface

| Plugin | What it adds |
|---|---|
| `superpowers` | brainstorming, test-driven development, systematic debugging, and subagent-driven development with review. Several Palmface skills point at it (`superpowers:brainstorming` before planning, for example) and work without it |

## Everyday code work

| Plugin | What it adds |
|---|---|
| `commit-commands` | commit, push and pull-request commands |
| `code-review` | pull-request review by several agents, filtered by confidence |
| `pr-review-toolkit` | review agents for comments, tests, error handling, types and code quality |
| `code-simplifier` | an agent that tidies recently changed code without changing behaviour |
| `feature-dev` | a feature workflow: exploring the code, designing, then a quality review |
| `security-guidance` | security warnings on edits and a review of the diff |
| `claude-md-management` | auditing and improving `CLAUDE.md` files |
| `skill-creator` | creating, improving and measuring skills |
| `plugin-dev` | building your own Claude Code plugins |
| `claude-code-setup` | recommends hooks, skills and subagents for a codebase |

## Language servers (code intelligence)

`typescript-lsp`, `pyright-lsp`, `gopls-lsp`, `rust-analyzer-lsp`. Each needs its language's
server installed; the plugin's page says which.

## Browser, docs and front end

| Plugin | What it adds |
|---|---|
| `playwright` | browser automation: pages, screenshots, forms, end-to-end tests |
| `chrome-devtools-mcp` | inspect a live Chrome: performance traces, network, console |
| `context7` | up-to-date library docs (it talks to a hosted service) |
| `frontend-design` | distinctive, production-grade front-end work |
| `playground` | small interactive HTML explorers |

## Ways of working

| Plugin | What it adds |
|---|---|
| `explanatory-output-style` | Claude explains its implementation choices as it goes |
| `learning-output-style` | Claude leaves meaningful pieces for you to write |
| `ralph-loop` | runs Claude on the same task repeatedly until it is done |
| `hookify` | write your own hooks from plain rules |
| `serena` | semantic code navigation and refactoring through language servers |
| `github` | GitHub's MCP server: issues, pull requests, search (needs a GitHub sign-in) |

Other plugins in the marketplace connect to services you have an account with, such as
databases, hosting, design tools and note apps. Browse them with `/plugin`.
