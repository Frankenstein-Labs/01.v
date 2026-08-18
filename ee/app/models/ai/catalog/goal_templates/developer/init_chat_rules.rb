# frozen_string_literal: true

module Ai
  module Catalog
    module GoalTemplates
      class Developer
        class InitChatRules
          TEMPLATE = <<~GOAL.strip
            Initialize Duo Chat custom rules for repository
            `%{project_full_path}` (default branch: `%{default_branch}`).

            **Your task:** analyze the repository's stack and conventions, then create
            `.gitlab/duo/chat-rules.md` and open a merge request.

            ## Background

            `.gitlab/duo/chat-rules.md` holds project-level custom rules. Once the file is
            committed, GitLab Duo reads it into context for GitLab Duo Chat, agents, and flows
            — every Agent Platform surface except the Code Review Flow. Use it to apply your
            team's preferences and standards to the output Duo generates.

            These rules are GitLab-only. They are distinct from `AGENTS.md`, which follows the
            portable `agents.md` standard that non-GitLab AI tools also read and is best for
            documenting project structure, monorepo layout, and directory-specific
            conventions. Keep `chat-rules.md` focused on preferences and team standards that
            `AGENTS.md` does not already cover, and do not duplicate `AGENTS.md`.

            They are also separate from `.gitlab/duo/mr-review-instructions.yaml`, which only the
            Code Review Flow reads to score merge requests. That file owns review criteria, so do
            not restate its rules here.

            ## Phase 1 — Analyze

            Inspect the repository:

            1. Identify the languages, frameworks, and build tools from source and build files
               (`pom.xml`, `package.json`, `pyproject.toml`, `go.mod`, `Gemfile`,
               `Cargo.toml`, `composer.json`, `*.csproj`, and so on), including the framework
               in use (for example, Spring, Rails, Django, React). Treat a language or area as
               present only if it has real, non-empty source files — an empty, stub, or
               placeholder file is not evidence; ignore it.

            2. Read existing convention sources so the rules reflect what the project already
               documents: `AGENTS.md`, `CONTRIBUTING.md`, a `STYLEGUIDE`, linter and formatter
               configs (`.rubocop.yml`, `.eslintrc*`, `.prettierrc`, `ruff.toml`,
               `.editorconfig`), any `.gitlab/duo/mr-review-instructions.yaml`, and the
               framework's own conventions.

            3. If an `AGENTS.md` already exists, read it and do NOT repeat its rules. `AGENTS.md`
               is the portable standard for project structure and conventions; capture here only
               the GitLab Duo preferences and team standards it does not already cover.

            ## Phase 2 — Write `.gitlab/duo/chat-rules.md`

            Create a new branch from `%{default_branch}` and write `.gitlab/duo/chat-rules.md`
            as a short Markdown list of rules, one rule per bullet:

            ```markdown
            - <a specific, actionable rule tuned to this project>
            - <a specific, actionable rule tuned to this project>
            ```

            Rules for a good file:

            - Make every rule **specific to this project's detected stack** and **actionable**
              in a conversation (for example, "Use the Maven wrapper `./mvnw`, never a global
              `mvn`", "Format Java with Spring Java Format", "Prefer Spring Data JPA derived
              queries over hand-written SQL", "Do not suggest returning raw entities from
              controllers — map to a DTO").
            - Focus the rules on **how Duo should generate output for this project**: coding-style
              preferences, conventions to follow, and team standards to enforce (for example,
              "prefer concise explanations", "always use single quotes for JavaScript strings").
            - Write each rule as a single terse clause. Keep the file concise — every rule is
              read into context on each run, so omit generic advice ("write tests", "use
              meaningful names") and anything already enforced by a linter config.
            - Do NOT duplicate `AGENTS.md` (the portable standard for project structure,
              conventions, and monorepo layout), and do NOT restate rules already covered by
              `.gitlab/duo/mr-review-instructions.yaml` — the Code Review Flow owns those.
            - Do not include secrets, credentials, or environment-specific values.

            Write only as many rules as the evidence supports, each grounded in a specific
            finding from Phase 1. Skip any language or area with no real code to learn from — do
            not pad the list to reach a count, and do not add baseline best-practice rules for a
            stack the repository does not actually use yet.

            ## Phase 3 — Open a draft merge request

            Commit the file on the new branch and open a draft merge request targeting
            `%{default_branch}`, assigned to @%{triggered_by_username}. In the MR description,
            briefly explain:

            - The stack and conventions detected, and which sources informed each rule.
            - Why each rule belongs in `chat-rules.md` rather than `AGENTS.md`.
            - That the user should review and refine the rules before merging, and that adding
              a Code Owners entry for `.gitlab/duo/` protects the file from unreviewed changes.
          GOAL

          def self.template
            TEMPLATE
          end

          def self.vars(resource:, params: {})
            {
              project_full_path: resource.full_path,
              default_branch: resource.default_branch_or_main,
              triggered_by_username: params[:triggered_by_username].to_s
            }
          end
        end
      end
    end
  end
end
