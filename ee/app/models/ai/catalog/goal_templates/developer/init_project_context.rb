# frozen_string_literal: true

module Ai
  module Catalog
    module GoalTemplates
      class Developer
        class InitProjectContext
          TEMPLATE = <<~GOAL.strip
            Initialize Duo Agent Platform project context for repository `%{project_full_path}` (default branch: `%{default_branch}`).

            **Your task:** analyze the repository and create an `AGENTS.md` file, then open a merge request.

            ## Phase 1 — Analyze

            Retrieve the current user ID (for MR assignment), then explore the repository:

            1. Read tooling configs to extract exact commands: pyproject.toml, setup.cfg,
               .pylintrc, ruff.toml, .flake8, mypy.ini, Gemfile, .rubocop.yml, package.json,
               .eslintrc*, tsconfig.json, Makefile, Rakefile, .gitlab-ci.yml, pytest.ini,
               jest.config.*.

            2. Read workflow/documentation files for conventions: README.md, CONTRIBUTING.md,
               lefthook.yml, commitlint.config.*, .markdownlint*.

            3. Note any subdirectories with their own distinct tooling or a different language.

            ## Phase 2 — Write AGENTS.md and open a merge request

            Create a new branch from `%{default_branch}`,
            then create a root `AGENTS.md` with this header:

            ```
            # AGENTS.md
            This file provides guidance to GitLab Duo when working in this repository.
            ```

            **Keep the file concise.** Every line has a per-invocation cost because agents read
            it on every task. Omit anything an agent can discover on its own. Do NOT restate
            information already in README.md or CONTRIBUTING.md — agents read those directly.

            Include only sections with direct evidence from the analysis, prioritising content
            the agent cannot easily discover itself:

            - **Non-obvious Commands** — exact commands that differ from the language default
              (e.g. `bin/spring rspec` not `rspec`, `scripts/lint-doc.sh` not `markdownlint`).
              Do not include standard commands an agent would try first. Do not invent or
              generalize commands.
            - **Gotchas and Constraints** — hard rules that would cause mistakes if unknown
              (e.g. "EE code goes in `ee/`", "do not modify `generated/` — run `make generate`",
              "feature flags must use `bin/feature-flag`"). Only include what is documented or
              evident in the repo.
            - **Non-standard Tooling** — only when the project uses a non-default tool that an
              agent would not infer (e.g. "use `pdm` not `pip`", "run `asdf install` first").
            - **Architectural Overview** — only if the structure is genuinely non-obvious and
              not described in existing docs. Omit entirely if the layout is self-evident or
              already covered by README.md or CONTRIBUTING.md.

            Do NOT include: generic advice ("write tests", "follow PEP 8"), style rules already
            enforced by linter configs, or boilerplate for tools not present in this repo.
            Incorporate relevant guidelines from any CLAUDE.md or .cursorrules found. Create a
            sub-AGENTS.md only for subdirectories that have actual code AND distinct tooling
            differing from the root.

            Commit and open a draft merge request targeting `%{default_branch}`, assigned to the current user.
          GOAL

          def self.template
            TEMPLATE
          end

          def self.vars(resource:, **_)
            {
              project_full_path: resource.full_path,
              default_branch: resource.default_branch_or_main
            }
          end
        end
      end
    end
  end
end
