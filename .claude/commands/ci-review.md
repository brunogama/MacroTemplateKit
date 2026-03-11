---
description: Run parallel code reviews using each .github/instructions/ checklist, then merge into a single detailed report
---

<objective>
Perform an exhaustive code review of the current branch's changes by running one parallel review agent per checklist file found in `.github/instructions/`.

Each agent reviews the diff independently against its own checklist, then all results are merged into a single structured verdict.
</objective>

<context>
- Changed files: !`git diff --name-only $(git merge-base HEAD main)..HEAD`
- Full diff: !`git diff $(git merge-base HEAD main)..HEAD`
- Instruction files: !`ls .github/instructions/`
</context>

<process>
1. List every file in `.github/instructions/`.
2. Read each file to extract the review checklist it contains.
3. For each checklist file, spawn a **parallel Agent task** with:
   - The full diff of the current branch vs main.
   - The checklist content from that file.
   - Instructions to review every changed Swift file against the checklist, citing file paths and line numbers for any finding.
   - Instructions to classify each finding as **Blocker**, **Major**, or **Info**.
4. Wait for all agents to complete.
5. Merge all agent results into a single report with the structure below.

## Report structure

### Summary
One-paragraph overall assessment.

### Verdict
**REJECT** | **FIX BEFORE RELEASE** | **ACCEPT** per the rubric:
- Reject: any Blocker unchecked.
- Fix before release: Blockers clear but Majors remain in security, concurrency, persistence, or correctness.
- Accept: no Blockers, Majors either resolved or explicitly noted.

### Findings by checklist

For each instruction file, a section titled with the file name containing:
- A table of findings: `| Severity | File:Line | Finding | Recommendation |`
- Or "No issues found" if clean.

### Blockers (aggregated)
All Blocker-level findings from every checklist in one place.

### Majors (aggregated)
All Major-level findings from every checklist in one place.

### Actionable next steps
Numbered list of concrete actions to resolve open findings, ordered by severity.
</process>

<success_criteria>
- Every instruction file in `.github/instructions/` was used as a review checklist.
- Review agents ran in parallel, not sequentially.
- Every changed Swift file was reviewed against every applicable checklist.
- Findings cite specific file paths and line numbers.
- Final report uses the exact structure defined above.
- Verdict follows the rubric from the merge-gate checklist.
</success_criteria>
