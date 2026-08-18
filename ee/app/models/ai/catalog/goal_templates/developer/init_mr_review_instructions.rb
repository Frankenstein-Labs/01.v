# frozen_string_literal: true

module Ai
  module Catalog
    module GoalTemplates
      class Developer
        class InitMrReviewInstructions
          TEMPLATE = <<~GOAL.strip
            Initialize Duo Code Review custom instructions for repository
            `%{project_full_path}` (default branch: `%{default_branch}`).

            **Your task:** analyze the repository's languages and conventions, then create
            `.gitlab/duo/mr-review-instructions.yaml` and open a merge request.

            ## Background

            The Code Review Flow reads `.gitlab/duo/mr-review-instructions.yaml` from the
            default branch and appends the matching instructions to its standard review
            criteria. Each instruction group targets specific files through glob patterns,
            so a rule only applies to the files it is meant for.
            Schema reference:
            https://docs.gitlab.com/user/duo_agent_platform/customize/review_instructions/

            Without this file, every Code Review Flow run uses only the default criteria and
            never enforces this project's own conventions.

            ## Phase 1 — Analyze

            Retrieve the current user ID (for MR assignment), then inspect the repository:

            1. Identify the languages and file types present, from source files and build
               files (`pom.xml`, `package.json`, `pyproject.toml`, `go.mod`, `Gemfile`,
               `Cargo.toml`, `composer.json`, `*.csproj`, and so on).

            2. Note the directory layout so file patterns match the real scope of each rule.
               For example, scope a Rails-controller rule to `app/controllers/**/*.rb`, not
               `**/*.rb`. Identify which directories hold tests so they can be excluded with
               `!` patterns when a rule should not apply to them.

            3. Look for existing convention sources the rules should reflect: a
               `CONTRIBUTING.md`, a `STYLEGUIDE`, linter configs (`.rubocop.yml`,
               `.eslintrc*`, `ruff.toml`, `.golangci.yml`), or an `AGENTS.md`. Prefer
               encoding standards the project already documents over generic advice.

            ## Phase 2 — Write `.gitlab/duo/mr-review-instructions.yaml`

            Create a new branch from `%{default_branch}` and write
            `.gitlab/duo/mr-review-instructions.yaml` using this schema:

            ```yaml
            instructions:
              - name: <instruction group name>
                fileFilters:
                  - "<glob pattern>"      # files this group applies to
                  - "!<glob pattern>"     # prefix with ! to exclude
                instructions: |
                  1. <specific, actionable review rule>
                  2. <specific, actionable review rule>
            ```

            Rules for a good file:

            - `name` and `instructions` are required for every group. `fileFilters` is
              optional, but add it to scope each rule to the files it applies to; use
              `**/*` only for a rule that genuinely applies to every file.
            - Write **specific, actionable** rules the reviewer can check against a diff
              (for example, "verify public methods have YARD documentation"), not vague
              guidance like "document your code".
            - Add only standards that are **specific to this project** and that a default
              review would not already apply. Skip generic advice such as "add error
              handling" or "use meaningful names".
            - Create one group per language or concern you found in Phase 1 (for example,
              a group per language, plus groups for migrations, CI config, or tests where
              the project has them). Keep each group's patterns aligned to its real scope.
            - Do not include secrets, credentials, or environment-specific values.

            ## Phase 3 — Validate and open a draft merge request

            Before committing, confirm the file parses as YAML and that every group has a
            non-empty `name` and `instructions`. The Code Review Flow skips an invalid file
            in full with no error shown, so a malformed file would silently leave the
            project with no custom instructions.

            Commit the file on the new branch and open a draft merge request targeting
            `%{default_branch}`, assigned to the current user. In the MR description,
            briefly explain:

            - The languages and conventions detected, and which sources informed them.
            - What each instruction group covers and why its file patterns are scoped that way.
            - That the user should review and refine the rules before merging, and that
              adding a Code Owners entry for `.gitlab/duo/` protects the file from
              unreviewed changes.
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
