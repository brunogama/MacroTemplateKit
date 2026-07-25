# Issue Tracker: Local Markdown

Issues for MacroTemplateKit are tracked as markdown files in `.scratch/` at the repo root.

## Layout

```
.scratch/
└── <feature-or-issue-name>/
    └── issue.md
```

Each issue is a directory with an `issue.md` file describing the work.

## Workflow

Skills like `to-tickets`, `to-spec`, and `qa` will:

- **Read** issues from `.scratch/<name>/issue.md` to understand what work is pending
- **Write** new issues as `.scratch/<new-name>/issue.md` when creating tasks
- **Update** existing issues by editing the markdown files directly

This approach is ideal for solo projects and repos without a remote issue tracker. Issues stay close to the code and ship in commits.

## Consuming Issues

To view all open issues:

```bash
ls -la .scratch/
```

To create a new issue:

```bash
mkdir -p .scratch/<feature-name>
echo "# <Issue Title>

Description here.
" > .scratch/<feature-name>/issue.md
```

Agent skills will discover and read these files automatically.
