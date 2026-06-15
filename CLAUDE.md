# User-level preferences

Applies to every repo. Per-repo specifics live in each repo's `docs/` — repo-level CLAUDE.md files have been retired.

## Who I am

I'm the developer for the **commercialiser of BREEDPLAN**. My remit is the
data-movement and orchestration layer: ingest, lakehouse storage, extract
formatting, pipeline orchestration, reporting.

**I do NOT write or have access to the Fortran code** that runs the actual
genetic evaluation. That's the scientists' (AGBU) domain. I feed it inputs
and consume its outputs.

**Treat moorun's loader column names and Fortran-format claims as best
effort, not ground truth.** The scientists supply them, and I've proven
several wrong over time. When designing an extract or output file, always
cross-check against canonical SQL (ILR2 reference extracts in
`~/c/bpingest/ref/`) and any sample output files we have, not just what the
loader source code says.

**Always look at the lore before guessing.** `~/c/moorun/docs/lore/` is the
authoritative knowledge base for BREEDPLAN file formats, column meanings,
code tables, and magic numbers (start at its `README.md` index). Whenever I
ask about an extract/output file, a column, a single-letter flag, a record
type, or any "what does this code mean" question — read the relevant lore
file FIRST and answer from it. Don't reverse-engineer the meaning from
loader/builder source code and present that as the answer; the lore is the
ground truth and the source is the implementation. If the lore is missing or
thin on the topic, say so and add to it rather than inferring silently. Note
that ILR2 is the canonical extract path — moorun's BFF builders mirror ILR2,
so the lore documents both; don't assume an ILR2 file came from the BFF code.

**Always write new findings back to the lore — don't wait to be asked.**
Whenever a session turns up a durable BREEDPLAN fact (a column meaning, code
table, magic number, file-format detail, a correction to existing lore, or a
load-bearing pipeline behaviour like where/why a filter runs) — proactively
add or update the relevant `~/c/moorun/docs/lore/` file as part of the same
turn, and add a one-line entry to its `README.md` index if it's a new topic.
I will often forget to prompt you to do this; treat capturing the finding as
part of finishing the task, not an optional extra. Cite the authoritative
source (file on disk, SQL, sample output, or "confirmed by running X") and
note when/where it was verified, per the lore's own conventions. Keep it
terse and one-fact-per-place. (The moorun lore edit still needs committing
like any other change — follow the normal commit-approval gate.)

Solo-ish dev working across the ABRI BREEDPLAN stack. All repos live under
`~/c/` (server reinstalled 2026-06-04 — everything consolidated there):

- `~/c/bpingest` — BFF ingestion, writes to glake-bpi Delta tables
- `~/c/moorun` — pipeline orchestrator, consumes glake-bpi
- `~/c/gpipe` — genomic imputation pipeline
- `~/c/gsingest` — GenSELECT ingestion
- `~/c/glake` — shared data lakehouse library (Delta Lake on Azure)
- `~/c/dash-reports` — Dash/Plotly reporting app

Cross-repo reads are routine — feel free to grep `~/c/glake`, `~/c/moorun`, etc. when tracing schemas or consumers.

## Tooling (universal)

- **Package manager**: `uv` — use `uv run <cmd>`, `uv sync`, `uv add`. Never touch pip directly.
- **Task runner**: `just` — check the Justfile first for the canonical invocation.
- **Linter/formatter**: `ruff`. 160 char line length, double quotes, no docstrings required (D1 ignored).
- **Python**: 3.12+. Don't use `from __future__ import annotations` — unnecessary.
- **Logger**: `loguru` (via the repo's `logger.py`), never stdlib `logging`.
- **Testing**: `pytest`. Use `monkeypatch` (built-in), not `mocker` — `pytest-mock` is not a dep anywhere.
- **DataFrames**: Polars. Don't spread pandas into new code. If a loader returns pandas, convert at the boundary with `pl.from_pandas()`.

## Workflow

- **Branch**: work on `main` by default unless the repo says otherwise.
- **Lint before finishing**: `uv run ruff check <dir>/` on changed files. Fix errors, don't leave them. If something genuinely needs suppressing, use the repo's existing convention (`# noqa:`, `# type: ignore`).
- **Type-check before finishing**: `uv run pyright` on any repo that has a `[tool.pyright]` block. Drive *errors* to zero (warnings are the known DataFrame-boundary backlog, non-blocking). Localize unavoidable pandas/polars stub noise with a file-level `# pyright: <rule>=false` pragma — never a global rule downgrade beyond the established five (reportArgumentType/AttributeAccessIssue/CallIssue/IndexIssue/OptionalSubscript). All stack repos except dash-reports carry this config; the shared CI gate runs it too.
- **Run tests after changes**: `uv run pytest`. If tests break, fix before moving on. Add tests for new code.
- **Don't use `ruff format` broadly** — it can destroy multiline Polars chains. Format specific files only if needed.
- **Never `cd <path> && …` in a Bash command.** Use absolute paths or per-tool directory flags instead — `git -C <path> <cmd>`, `ls <path>/`, `grep -r … <path>/`, `uv run --directory <path> …`, `just -d <path> …`. The `cd`-before-command shape trips Claude Code safety gates (untrusted git hooks; `cd`+redirection path-resolution bypass) that can't be allow-listed, so it prompts every single time — and worse, a silently-failed `cd` runs the rest against the wrong directory. Absolute paths sidestep the gate and remove the footgun.
- **Keep Bash statically analyzable so allow-rules actually match.** Claude Code's safety analyzer prompts on shell variable expansion (`$VAR`), `for`/`while` loops, and command substitution (`$(…)`) even when the underlying tool is allow-listed (e.g. `Bash(gh:*)`) — it can't prove what will run, and that gate isn't allow-listable. For one-off introspection, unroll into explicit literal commands (five `gh repo view abri-breedplan/<repo> …` lines, not `for r in …; do … $r …`). When a later command needs an earlier one's output (capture a SHA, then query CI by it), **split into separate Bash tool calls and inline the captured value as a literal** in the next call — let the agent turn be the variable, instead of one `SHA=$(…); … "$SHA"` blob. Only keep it in a single shell command when the dynamic shape is genuinely irreducible.
- **Cross-repo changes**: if you change glake schemas or bpingest contracts, run the consumer's tests too (e.g. moorun).
- **`plans/*.md` are committed** — they're working documents but kept in git so I can revisit decisions and you can see how intent evolved. Include them in commits alongside the implementation they describe.

## Testing philosophy

- **Every repo except `~/c/dash-reports` cares deeply about tests.** Coverage is uneven but climbing — moorun (~290 tests) and gpipe (~160) both have real suites now, others vary. Treat low coverage as a debt to pay down, not a license to skip.
- **Any non-trivial change adds or updates tests**, even in repos with small suites. A bug fix that lands without a regression test is half a fix.
- **`dash-reports` is the exception** — UI glue on top of parquet/glake data. Tests welcome but not required.
- **Cross-repo test discipline**: when a change spans a contract boundary (glake ↔ consumer, bpingest ↔ moorun), run both sides' suites before declaring done.

## Cross-repo consistency

I hate drift between repos. When you see a better pattern in one repo that's missing in another, flag it so we can align — don't silently let them diverge.

### Justfile shape (every repo except `~/c/dash-reports`)

All non-dash Justfiles follow the same skeleton. Treat deviations in a specific repo as drift to be fixed when touching that area:

- **`repo := "{name}"`** variable at top
- **`cli *args`** — invoke the package's CLI module with glake env sourced (`uv run python -m {repo}.cli.main {{args}}`)
- **`run *args` / `run-prod *args`** — dev vs prod, differing only in which glake env file they source (`glake.dev.env` vs `glake.env`) + slack env for prod-capable runs
- **`script name *args`** — run a one-off from `scripts/{name}.py`
- **`release bump='patch'`** — semver bump that updates `pyproject.toml`, `{repo}/__init__.py` (`__version__`), `uv.lock`, then commits, tags `v{new}`, pushes both
- **Env sourcing idiom**: `set -a && . /etc/breedplan/envs/glake.dev.env && set +a` (or multi-line with `set -euo pipefail` inside a bash recipe)

`~/c/dash-reports` is Docker-centric and doesn't follow this shape — don't try to retrofit it.

### Shared env files

- `/etc/breedplan/envs/glake.dev.env` — dev glake credentials
- `/etc/breedplan/envs/glake.env` — prod glake credentials
- `/etc/breedplan/envs/slack.env` — Slack bot token for pipeline notifications
- `.env` (gitignored, per-repo) — repo-specific secrets (e.g. bpingest's ILR2 PostgreSQL connection)

### Pipeline repo shape (bpingest, moorun, gpipe, gsingest)

All the pipeline repos share an architectural spine:

- **Package layout**: `{repo}/cli/main.py` (typer), `{repo}/steps/s{NN}_{name}.py`, `{repo}/common/` for shared helpers, `{repo}/config.py` + `{repo}/logger.py`
- **Step signature**: `def run(rc, ...) -> None` — where `rc` is the repo's runner config; extra args vary (`ctx`, `step`, `exe`, `report`)
- **Numbered steps** execute sequentially; the runner supports `--only`, `--start`, `--end-after`, `--skip`
- **Config split**: pydantic-settings `BaseAppConfig` (env-prefixed, e.g. `BPINGEST_`, `GPIPE_`, `MOORUN_`) with `DevelopmentConfig` / `ProductionConfig` chosen by `APP_ENV`
- **YAML config** loaded from the split layout under `/breedplan7/configs/`: run-scoped configs at `runs/{RUN}/{name}.yaml` (moorun `bp.yaml`/`genselect.yaml`, `gpipe.yaml`, `bpmatch.yaml`), society-scoped files at `socs/{SOC}/{file}` (`bpingest.yaml`, `traits.csv`, `extract.sh`). The old flat `configs/{SOC}/` layout is gone.
- **Version in two places**: `pyproject.toml` and `{repo}/__init__.py` — the `just release` recipe keeps them in sync
- **Observability**: OpenTelemetry (disabled in dev, enabled in prod) + Slack notifications on completion/failure
- **Logger**: `from {repo}.logger import logger`

### When drift is OK

Don't force consistency where it genuinely doesn't fit:

- `~/c/dash-reports` is a web app — Docker-first Justfile, pandas in EBV reports, no typer CLI
- `~/c/glake` is a library, not a pipeline — no `run` recipe, no steps, no `APP_ENV`
- Rendering the release recipe portable across repos is valuable; forcing `dev` or `build` recipes to match isn't

If a pattern appears in 3+ repos, it's a convention. If it's in 1-2, it's a choice — worth copying only if it'd actually help.

## Commit discipline

- **Never commit without explicit approval.** After changes pass lint + tests, stop and summarise what's staged. Wait for "yes" (or similar) before `git commit`. I review every bulk change in the VSCode editor first — the approval gate is what makes that review possible. The permission allowlist may permit `git commit`, but the gate is still in force: ask, don't commit.
- Prefer creating new commits over amending.
- Never use `--no-verify`, `--force`, or `reset --hard` without explicit ask.
- Follow the repo's commit message style (check `git log` first).

## Communication

- **Never assume — ask if unsure.** Especially on anything cross-repo, anything that touches glake schemas, or anything with "should I also…" ambiguity.
- **If a prompt has an unresolved referent ("these", "this", "that", "the thing we discussed") and I haven't told you what it points to, ASK before exploring.** Don't go spelunking the repo to guess what I meant — a wrong guess wastes Opus tokens and my time. The moment you catch yourself thinking "I don't know what X refers to," stop and ask. Investigate-before-asking applies to *how to do* a known task, not to *what the task even is*.
- **Ask more questions — lean toward checking in, not toward long autonomous runs.** The moorun lore and the breedplan-diag agent are nowhere near complete enough for you to disappear for 20 minutes and come back with something right. The domain knowledge you'd need to make good independent calls (BREEDPLAN file semantics, ILR2 vs BFF quirks, pipeline ordering) isn't fully captured yet, so unwritten context lives in my head. When a task involves a domain assumption, an architectural choice, an ambiguous scope, or a "which of these approaches" fork, STOP and ask rather than picking and building. Short feedback loops with me beat a confident long run on a wrong premise. Surface your uncertainty early and often; a 30-second question is cheaper than 20 minutes of misdirected Opus work. (As the lore and diag agent mature this can relax — for now, default to involving me.)
- Terse responses. Skip trailing summaries when the diff tells the story.
- Default to no code comments. Only write a comment when the *why* is non-obvious.
- Don't create doc files (`*.md`) unless I ask.
- **Don't use the memory system.** I dislike it. Put durable knowledge in repo markdown docs (e.g. each repo's `docs/`), not memory files.

## Model defaults

- **Main session**: Opus 4.7, **medium** reasoning. Don't default to xhigh — it burns quota disproportionately for marginal gains. Only step up to xhigh if medium has already failed on the specific problem.
- **Subagents**: Sonnet 4.6 or Haiku 4.5 — see "Subagent discipline" below.

## Subagent discipline (cost control)

I pay per Opus token. Exploration is the biggest waste source.

- **Early exploration** (figuring out the shape of a problem, 2-3 iterative greps): keep on the main session. You can't batch what you can't yet specify.
- **Once the question is crisp** ("verify X across these files for these IDs", "pull all callers of Y", "read loader Z and summarise"): spawn a subagent with `model: sonnet` or `model: haiku` instead of doing it inline. One packaged request, one structured return, synthesis stays on the main Opus session.
- Rule of thumb: if you're about to do 4+ sequential reads/greps on a well-defined question, stop and delegate.
- Don't delegate the synthesis. The "what does this mean" step is why I'm on Opus.

## Security / destructive ops

- Confirm before: deleting files/branches, dropping tables, force-push, `rm -rf`, modifying CI.
- Investigate unfamiliar state (unknown branches, lockfiles, stashes) before deleting. It's probably my in-progress work.
