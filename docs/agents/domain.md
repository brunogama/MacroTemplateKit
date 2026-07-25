# Domain Docs: Single-Context Layout

MacroTemplateKit uses a single-context domain doc layout: one `CONTEXT.md` at the repo root, and architecture decisions in `docs/adr/`.

## File Locations

- **`CONTEXT.md`** (repo root) — project overview, terminology, architecture summary
- **`docs/adr/`** (repo root) — Architecture Decision Records in markdown

## Consumer Rules

Agent skills read these files in this order:

1. **CONTEXT.md** — to understand project scope, terminology, and current architectural shape
2. **docs/adr/*.md** — to trace why past decisions were made and what constraints they enforce

Use CONTEXT.md for:
- Project goals and non-goals
- Core terminology and ubiquitous language
- High-level architecture summary
- Constraints and platform limits
- Benchmarks and performance targets

Use ADRs (in `docs/adr/`) for:
- Technical decisions that have trade-offs
- Why a design was chosen over alternatives
- What each decision enables or prevents downstream
- References to code that implements the decision

## Keeping Docs Fresh

Whenever a significant architectural decision changes:

1. Update `CONTEXT.md` if the change affects terminology, scope, or core architecture
2. Add an ADR to `docs/adr/` documenting the decision and its rationale
3. Update commit messages to reference the ADR (`see docs/adr/0002-example.md`)

Agent skills will use these files to propose features and fixes that align with your current design, not past designs.
