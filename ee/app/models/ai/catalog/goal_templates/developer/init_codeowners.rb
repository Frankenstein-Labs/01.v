# frozen_string_literal: true

module Ai
  module Catalog
    module GoalTemplates
      class Developer
        class InitCodeowners
          DAP_SECTION = '[GitLab Duo Agent Platform]'

          TEMPLATE = <<~GOAL.strip
            Protect agent-instruction files in repository
            `%{project_full_path}` (default branch: `%{default_branch}`) by adding a
            `#{DAP_SECTION}` section to the `CODEOWNERS` file.

            **Your task:** create or append to `CODEOWNERS` so the agent-instruction files
            require code-owner review before changes merge, then open a draft merge request.

            ## Background

            Several files are read into LLM context as authoritative instructions on every
            Chat conversation and flow run:

            - `AGENTS.md` (root and any subdirectory copies)
            - `.gitlab/duo/` (chat rules, MCP config, agent config, review instructions)
            - `skills/` (skill definitions)

            A contributor who can land a commit to any of these files can inject instructions
            the model will treat as authoritative on subsequent runs — the classic indirect
            prompt-injection vector. `CODEOWNERS` is the built-in GitLab mechanism that
            requires explicit review on these paths before changes merge.

            ## Phase 1 — Analyze

            Inspect the repository:

            1. Check whether a `CODEOWNERS` file already exists at any standard path:
               `CODEOWNERS`, `docs/CODEOWNERS`, or `.gitlab/CODEOWNERS`.
               - If it exists, read its content so you can **append** without disturbing
                 existing entries.
               - If it does not exist, you will create one at the repository root.

            2. If a `#{DAP_SECTION}` section already exists, stop — the protection is already
               in place — and tell the user instead of opening a duplicate merge request.

            3. Choose a **real, existing** owner — never a placeholder, a project path, a bot,
               or a service account (for example the Duo `@duo-*` identities): a service
               account must never own these files, or the agent could approve its own changes
               to the instructions it follows. Resolve the owner in this order, and confirm via
               the API that your choice exists before using it:
               a. Reuse a `@group/team` or `@user` already present in the existing
                  `CODEOWNERS` file.
               b. Otherwise, use the project's members with at least the Maintainer role, as
                  `@user` handles (excluding bot and service accounts).
               c. Otherwise, if the project belongs to a group whose reviewers are real users,
                  use that group's `@group/full-path` handle.
               d. Only if none of the above resolves to a real user or group, use
                  @%{triggered_by_username}.

            ## Phase 2 — Write or append to `CODEOWNERS`

            Create a new branch from `%{default_branch}`, then append this section to the
            existing `CODEOWNERS` file (or create the file with this content if none exists):

            ```
            #{DAP_SECTION}
            AGENTS.md @<owner>
            **/AGENTS.md @<owner>
            .gitlab/duo/ @<owner>
            skills/ @<owner>
            ```

            Rules:
            - Cover exactly this LLM-injection surface and no more:
              `AGENTS.md`, `**/AGENTS.md`, `.gitlab/duo/`, and `skills/`.
            - In the template above, `@<owner>` is a stand-in: replace every occurrence with
              the real owner you resolved in Phase 1. Never write the literal text `@<owner>`.
            - Each owner must be a real, existing `@user` or `@group/team` handle — never a
              project path, a bot, or a service account. GitLab silently ignores a CODEOWNERS
              line whose owner is not a real user or group, which would leave the path
              unprotected.
            - Do NOT add a wildcard `* @owner` fallback unless the user explicitly asks for one.
            - Never overwrite existing entries — append after the last line, separated by a
              blank line.
            - Write to the `CODEOWNERS` path that already exists (`CODEOWNERS`,
              `docs/CODEOWNERS`, or `.gitlab/CODEOWNERS`); if none exists, create `CODEOWNERS`
              at the repository root.
            - Do not include secrets, credentials, or environment-specific values.

            ## Phase 3 — Open a draft merge request

            Commit the file on the new branch and open a draft merge request targeting
            `%{default_branch}`, assigned to @%{triggered_by_username}. In the MR description:

            - State which `CODEOWNERS` path was created or updated.
            - List the protected paths and why each is part of the injection surface.
            - State which owner you assigned and how you resolved it (reused an existing entry,
              project maintainers, the project group, or @%{triggered_by_username}), and ask the
              user to confirm it is the right reviewer for these files — adjusting it if not.
            - Remind the user to enable "Require Code Owner approval" in the default branch
              protection settings so the entries are enforced.
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
