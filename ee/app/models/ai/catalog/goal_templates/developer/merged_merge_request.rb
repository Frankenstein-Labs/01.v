# frozen_string_literal: true

module Ai
  module Catalog
    module GoalTemplates
      class Developer
        class MergedMergeRequest
          TEMPLATE = <<~GOAL.strip
            The merge request %{resource_url} has just been merged.

            It was worked on by Duo Developer sessions with the following session IDs: %{session_ids}

            Turn ephemeral observations from these past developer-agent sessions into
            persistent repo memory, so the developer agent stops repeating mistakes and
            reaches its goals in fewer steps and tokens.

            ## Phase 1 — Save traces locally

            For each session ID listed above, dump its trace to the system temp dir
            (outside the repo, so it is never committed and does not depend on
            `.gitignore`):

            ```sh
            glab api "ai/duo_workflows/workflows/<SESSION_ID>/trace.jsonl" > "/tmp/trace-<SESSION_ID>.jsonl"
            ```

            ## Phase 2 — Analyze the traces

            Traces are JSONL (one event per line): agent reasoning, tool calls, tool
            results, final answers. Analyze with `run_command` shell tools (`jq`,
            `grep`, `wc`) — do NOT use `read_file`. Shell filtering is far more
            token-efficient than reading raw JSONL. Useful starting points:

            ```sh
            # Event-type histogram
            jq -r '.type // .event // keys[0]' /tmp/trace-<SESSION_ID>.jsonl | sort | uniq -c
            # Failed / retried commands
            grep -iE 'failed|error|not found|command not found|no such' /tmp/trace-*.jsonl
            ```

            Analyze all sessions collectively and dedupe findings. A finding that recurs
            across multiple sessions is the strongest evidence it is worth persisting —
            weight it highest.

            Apply two lenses, and for every proposed change cite the concrete evidence
            (session ID + what happened):

            **A. Corrective** — the trace shows something went wrong:

            - Repeated or failed `run_command` calls (wrong flags, wrong paths).
            - A binary/tool the agent needed but was missing, forcing multi-step workarounds.
            - Wrong assumptions about build/test/lint commands or repo conventions.
            - Time wasted rediscovering something that should already be documented.

            **B. Optimization audit** — even without an outright failure, is the existing
            harness well-structured? Read the current harness files and judge:

            - Memory file (`AGENTS.md`/`CLAUDE.md`) too long or full of task-irrelevant
              content: split into focused sections and link them by file reference to cut
              tokens.
            - A skill is outdated or unclear, causing the agent to take extra steps.
            - Env config missing a tool the agent repeatedly needs: add it once.

            Map each finding to a repo target using this rubric:

            | Signal | Target |
            | --- | --- |
            | General fact, command, or convention | Memory file (`AGENTS.md` / `CLAUDE.md`) |
            | Reusable multi-step procedure | Agent skill under `.agents/skills/<name>/SKILL.md` |
            | Missing/misconfigured tool or runtime | `.gitlab/duo/agent-config.yml` |

            Keep only high-signal, generalizable learnings. Discard one-off noise. If
            nothing meets the bar, skip Phase 3 — do not open an empty merge request.

            ## Phase 3 — Apply changes and open a merge request

            Detect the correct target and edit it with the right tool (some paths are
            protected):

            - **Memory file** — determine whether the repo uses `AGENTS.md`, `CLAUDE.md`,
              or one symlinked to the other (`ls -l AGENTS.md CLAUDE.md`); edit the real
              file with `edit_file`/`create_file_with_contents`. Do not assume `AGENTS.md`.
            - **Agent skills** — create/update `.agents/skills/<name>/SKILL.md` using a
              relative path with the normal file tools.
            - **Env config** — `.gitlab/duo/agent-config.yml` (its `setup_script:` list or
              `image:`). This path is on the file-tool security denylist, so the
              `read_file`/`edit_file`/`create_file_with_contents` tools cannot touch it.
              Read and edit it only via `run_command` (e.g. `cat .gitlab/duo/agent-config.yml`,
              then `sed -i` / append with a shell heredoc). Config is read from the default
              branch, so it must be committed to take effect.

            Then open one merge request:

            1. Create a new branch off the repo's default branch, e.g.
               `chore/distill-agent-memory-mr-%{merge_request_iid}`.
            2. Commit all changes following the repository's own commit message
               conventions; if none are documented, use a Conventional Commits message
               (`chore(agent): ...` or `docs(agent): ...`; header <= 100 chars).
            3. Open the merge request with `glab`. Group the description by target
               (Memory file / Skills / Env config) and, under each change, cite the
               session-id evidence that justifies it.

            ## Phase 4 — Report back

            Post a comment on the merged merge request %{resource_url} summarizing what
            you did: which sessions you analyzed, the key findings, and a link to the
            merge request you opened (or why no changes were needed).
          GOAL

          def self.template
            TEMPLATE
          end

          def self.vars(resource:, params: {}, **_)
            {
              resource_url: Gitlab::UrlBuilder.build(resource),
              merge_request_iid: resource.iid,
              session_ids: Array(params[:session_ids]).join(', ')
            }
          end
        end
      end
    end
  end
end
