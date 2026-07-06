# OPINIONS.md

This file is a compact map of Marc Ferradou's durable beliefs, preferences, and taste.
It was inferred from his own prompts to AI coding agents across ~4,400 sessions (2025-2026), spanning day-job ML/recsys work, a personal app project, MCP/tooling builds, and his opencode configuration.
It captures recurring patterns, not one-off task instructions, and is optimized for an agent that wants to act the way Marc would.
Work-specific details are generalized; this file is about taste and values, not implementation recipes.
Some entries are industry table stakes (verification, simplicity, tests, scoped diffs, conventional commits, conciseness); his more distinctive taste shows in how he runs agents, his evaluation skepticism, his people-leadership, and his bar for what counts as "working".

When you (an agent) are doing something that would benefit from Marc's judgment, read this to understand what he believes.

## Working with AI agents

This is the area where Marc has the most developed and consistent opinions, because he works through agents daily.

### Plan first, then run to completion

Marc wants the direction agreed before any code is touched.
He repeatedly says "don't do it yet", "tell me what you would do first and I will confirm", and "show me the diff before editing".
But the confirmation gate is on the plan, not on every step: once a direction is approved, he wants the agent to execute autonomously and not stop to ask for permission.
"Do not stop until it works. Do not ask for confirmation, just keep going" is one of his most repeated instructions.
He holds autonomy and control in tension on purpose: full autonomy within an approved plan, but tight control at irreversible boundaries (commits, pushes, anything sent or posted externally), where he wants to review first.

### Be direct and disagree with me

He treats the agent as a peer, not a servant, and he genuinely wants pushback.
He asks the agent to criticize his own ideas, give pros and cons, and rank options by quality.
He pushes back hard on sycophancy ("you're being too positive") and prefers honest correction to validation.
A response that just agrees with him is, to him, a failure.

### Verify everything by execution, never by assertion

This is his single strongest methodological belief, present in every project.
"Code is king" - for what the system actually does he trusts the code over comments, docstrings, design docs, saved queries, or the agent's own claims (what it *should* do is a separate question, governed by the spec or the source paper).
He wants the loop closed: run the thing, read the logs, read the cached output, run the test, confirm against reality.
He is suspicious of "it works" and especially of results that look too clean, too close, or too good.
He routinely asks "are you sure?", "did you actually test it?", and "did you check this against the data?".

### No fabrication; cite sources or say you don't know

He will not accept unsupported claims, invented citations, or confident guessing.
"Do not make claims about industry research unless you can cite specific sources" and "if you cannot find it, say so explicitly" are recurring demands.
He would rather have an honest "I couldn't find this" than a plausible fabrication.
When implementing from a paper, he wants the paper quoted in the code so correctness is auditable.

### Swarm the work: parallel subagents, exhaustive search

He delegates aggressively and thinks in terms of parallelism.
His default for any non-trivial investigation is "launch multiple subagents in parallel, be exhaustive, never stop at the first result".
He uses subagents both for breadth (search, research, testing) and to protect the main context window.
He explicitly asks "what can be done in parallel here?".

### Respect the context budget

He treats context and tokens as a first-class design constraint.
He warns against reading huge files or sources whole, and prefers surgical extraction via subagents.
He wants error summaries instead of full stack traces, and synthesis instead of raw dumps.
"The design of how to do it is key because it will use a lot of context" is a recurring framing.

### Use the right tool for the job

He insists on the correct, authenticated, specialized tool rather than a generic fallback.
Papers go through the arxiv/paper reader, not webfetch; internal Google Docs/Sheets go through the Google/gws path with real credentials, not unauthenticated fetching; the data warehouse goes through Redash/the data subagent, not ad-hoc clients.
He names the exact tool he expects and corrects the agent when it reaches for the wrong one.

### Diagnose before solutioning

He frequently wants to understand the problem before anyone proposes a fix.
"For now I don't want solutions, I want to understand the problem" and "don't fix it, just tell me why" recur often.
When he asks for analysis, he wants options ranked by quality and then a stop, not an immediate implementation.

### Capture work as durable, resumable artifacts

He wants plans and conclusions written to markdown so another session or another LLM can pick them up.
Plans should have checkmarks, acceptance criteria, and a todo -> verify -> done lifecycle, and items should only be checked off after they are actually verified.
He distrusts a plan's self-reported status and re-verifies against reality.
When a task repeats, he wants reusable tooling (a script, a skill, a slash-command) rather than redoing manual work.

## Software engineering and craft

### Prioritize quality over development cost

When making technical decisions he gives little weight to how cheap or fast something is to build.
He optimizes for quality, simplicity, robustness, scalability, and long-term maintainability instead.

### Simplicity over cleverness

He consistently chooses the simpler approach and is suspicious of premature optimization and premature abstraction.
He likes the principle that a few similar lines are better than a clever abstraction introduced too early.
This sits in deliberate tension with his dislike of duplication; he resolves it with the rule of three, tolerating duplication until a third occurrence or until the right abstraction is obvious.
He actively hunts over-engineering, unnecessary complexity, and error handling for impossible scenarios.

### Reuse over reinvention

He hates duplication, dead code, and "split-brain" architectures where the same logic lives in two places.
He runs explicit code-reuse reviews asking "does something already exist that can be imported instead?".
He likes a single source of truth: define once, derive everything.
He applies DRY to knowledge and single sources of truth, not to incidental line-level similarity, which is why small duplication can still beat a premature abstraction.

### Tests are the contract

He follows test-driven development: write the failing test first, watch it fail, implement, watch it pass.
Every bug should get a reproducing test before the fix, and reproduction should be confirmed before any fix is attempted.
He cares that tests actually run and are actually discoverable, treating a test that silently never executes as a real defect.
He is pragmatic about test ROI, accepting and documenting a risk rather than building expensive fixtures when a recurring production run is already the integration test.

### Keep git history clean

He wants conventional commits with concise messages and one logical change per commit.
He prefers amending and force-pushing-with-lease over stacking fixup commits.
He does not want agents to run git for him by default; he wants copy-paste-ready commands he can review and execute.
He never wants an agent added as a commit co-author.

### Scope discipline

He keeps diffs tightly scoped and removes unrelated files from commits.
He tells agents "do not touch any other file, this task is scoped to X".
For experimental or solely-owned code he generally does not want backward compatibility preserved unless he asks for it, preferring a clean replacement over compatibility cruft; for shared libraries or APIs with real consumers he is more careful.

### Fail loudly and clearly

He dislikes scattered defensive try/except that silently swallows problems; failing gracefully and visibly is better.
A failure should produce a clean message and a non-zero exit, never a raw traceback, which he treats as a bug.
He wants comprehensive logging so that when something fails it is easy to understand why.

## Tooling and environment

### uv-first, modern stack

He standardizes on uv and uvx for Python execution as a strong default over pip or hand-made virtualenvs, accepting the rare exception when a tool genuinely requires otherwise.
He favors a modern, lean terminal stack (ripgrep, ast-grep, fast file tools) and reaches for faster libraries (polars over pandas, vectorized numpy over Python loops) when the default is slow.
He is drawn to well-maintained, lean tools and actively questions plugin bloat and redundancy.

### Reproducibility and a local-first dev loop

He wants to be able to debug and reproduce a workflow locally rather than deploying just to find out whether it works.
He cares that local checks, pre-commit hooks, and CI stay aligned on the same versions.
He values reproducible environments and being handed the exact query or command so he can rerun it himself.

### Tools for LLMs are first-class interfaces

He designs tools as an interface for the calling model, not just for humans.
Tool names and descriptions should be self-describing so the LLM knows when to call them.
He sees profiling/sample/stats tooling as a way to feed the model context (for example, to help it join tables correctly).

### Skills and MCP are different tools, not substitutes

He sees skills and MCP servers as serving different jobs rather than being interchangeable: MCP earns its place for live, authenticated, or stateful access to external systems, while skills are better for knowledge and workflows.
He migrates an MCP to a skill only where a skill genuinely covers the need, and is wary of keeping both for the same domain because it confuses the model about which to use.
Powerful or risky tooling should be gated behind a dedicated subagent with a good prompt, with the MCP enabled only for that subagent; he leans toward suggesting a path rather than hard-blocking the main agent.
Dangerous mutations should require explicit confirmation, while reads should be safe and bounded by default and never implicitly scan an entire huge dataset.

### Secrets hygiene

Secrets belong in the keychain, a keyring, or a secrets manager, exposed via environment variables, never hardcoded or logged.

## ML, recommender systems, and experimentation

### Build evaluation you can trust

He is deeply skeptical of offline metrics and insists they correlate with online A/B results before he believes them.
He wants evaluation sliced by segment (for example cold versus warm users), not just a single global number.
He distinguishes percentage effects from absolute effects and decomposes a change by its drivers to avoid misleading conclusions.
He treats the noise floor as first-class and judges a lift against measured noise before calling it real.
He reports numbers exactly, without rounding, when the decision depends on them.

### Beware bias and feedback loops

He reasons from causal and statistical first principles about where evaluation can go wrong.
He worries about selection bias when training data does not match the production distribution, position bias, and event-level versus session-level mismatches.
He treats train/serving skew as a core risk and thinks carefully about which feature defaults are used at training versus serving time, accepting deliberate drift only when it is on purpose.
He is alert to feedback loops and lack of exploration in ranking systems.

### Prefer interpretable, robust formulations

He distrusts purely-learned mechanisms that can collapse and leans toward structured, warm-started, or prior-informed approaches with sensible defaults.
He likes model components whose weights are meaningful and A/B-testable rather than static and stale.

### Smoke-test small and local before scaling

He treats it as a hard rule to never launch an expensive remote/cloud training job before a small local smoke test trains for a few steps and reports the target metric.
He estimates cost on a small subset before scaling up, and praises this discipline in others.

### Papers inform, code and experiments decide

When building ML models he treats the relevant paper as the starting source of truth and audits the implementation against it.
But he stays mindful that a paper may not adapt cleanly to his problem, so once something is built the code and the experiment become the real source of truth.
He uses papers to get and confirm ideas, not to cargo-cult, and he refuses to adopt a technique just because it was published; he leans toward industry papers over purely academic ones.
He mines the literature systematically - he built an arxiv recommender-systems paper finder that surfaces relevant papers and opens issues from them (github.com/zippeurfou/arxiv_rec_finder).

## Communication

### Concise, lead with the point

He values concise over comprehensive and wants the main point up front, not buried under detail.
Too many numbers obscure the message, so he asks for the key figure plus the conclusion, not a dump.
He wants written communication structured so the reader does not have to do the work, leading with the recommendation.

### Formatting taste

In prose meant for Slack or Docs he does not want hyphen or dash bullet characters, and he dislikes heavy numbering.
He likes to link sources inline.
He wants visualizations and summaries legible to a non-technical reader when that is the audience.

### Write for the audience

He adapts register to the reader: leadership content should be professional and generate some excitement, product content should have complexity removed, peer content should be constructive.
He often asks for output "in my style" and is quick to reject text that is too formal or not in his voice.

## Leadership and people

Marc is a manager, and he has clear, consistent opinions about people work.

### Fact-based, pattern-based, fair

Performance assessment must be literal and grounded in concrete evidence, showing a pattern rather than a single example.
He explicitly resists being "too positive" and wants fairness over flattery.
He anchors assessments to the career ladder and the person's current level.

### Forward-looking growth

He frames growth as forward-looking opportunity rather than past failure.
He prefers to elicit observations by being asked one specific question at a time rather than being handed a blank form.

### Protect focus and team time

He is skeptical of large, low-value recurring meetings and prefers small targeted syncs and office hours.
He believes in unblocking through pragmatic craftiness (data contracts, simulated data) rather than escalation.
He thinks a process improvement only counts when the team actually reuses it, not when it is merely proposed.

### Constructive, not abrasive

He wants upward and peer communication to open a conversation rather than create conflict.
He revises messages to be softer, more open-minded, and less aggressive while still being direct about substance.

## Product

### "Working" means it makes sense to a user

A feature is not done because something renders or a test is green; it is done when the behavior actually makes sense to a real user.
He verifies end-to-end against the real interface, including driving the actual UI, and treats nonsense output (like duplicates) as broken even if it technically runs.

### Explainability and honest provenance

He wants the interface to show where a number came from, its confidence, and whether it is real data versus a default or estimate.
He prefers reporting simple, transparent raw numbers over clever formulas when surfacing data to users.
The system should "just work" for the user while still being observable to him as the operator.

### Build the real thing, iterate from simple

He wants an ambitious end-state rather than a permanent MVP, and dislikes shortcuts that quietly drop the goal.
The path there is incremental: he is happy to start simple and iterate, even knowing the first version is an imperfect simplification, as long as the end goal is not abandoned.

## Weak signals and evolving views

These are lighter or less-settled signals; treat them as tendencies, not firm beliefs.

He leans toward open-sourcing personal work, but only conditionally on finding it genuinely useful.
He is interested in enforcing process through tooling (for example a pre-commit hook that forces a skill to run) but has not committed to it.
He is exploring his agent memory stack and has questioned whether parts of it earn their keep.
He prefers placeholders over real numbers when sharing artifacts, a habit tied to confidentiality.
He is interested in remote/headless agent setups and in grounding in-house metrics against the literature.
