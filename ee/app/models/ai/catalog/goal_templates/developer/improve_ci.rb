# frozen_string_literal: true

module Ai
  module Catalog
    module GoalTemplates
      class Developer
        class ImproveCi
          TEMPLATE = <<~GOAL.strip
            Review and improve the GitLab CI configuration for `%{project_full_path}` (default branch: `%{default_branch}`). Open a draft MR with actionable improvements.

            ## Phase 1 — Analyze

            1. Read `.gitlab-ci.yml` and any files pulled in via `include:` directives.
            2. Note existing conventions (rules style, base job names, artifact flow, caching) — all changes must follow them.
            3. Identify improvement opportunities:
               - Missing or inefficient caching.
               - Jobs that could run in parallel (`needs:` / DAG).
               - Duplicated definitions that could use `extends:` or YAML anchors.
               - Overly broad `rules:`/`only:`/`except:` triggering unnecessary jobs.
               - Missing `interruptible: true` on eligible jobs.
               - Heavy Docker images replaceable with slimmer alternatives.
               - Missing `timeout:` on long-running jobs.
               - Missing security scanning (SAST, secret detection, dependency/container scanning).
               - Hardcoded secrets — replace with CI/CD variable references.

            ## Phase 1b — CI/CD Catalog

            Before writing a custom job, search this instance's catalog for a maintained component:
            ```
            glab api graphql -f query='{ ciCatalogResources(search: "<keyword>") { nodes { name webPath versions { nodes { name } } } } }'
            ```
            Prefer `components/*` (GitLab-maintained). If nothing fits, use an instance-wide `include: template:`, then custom YAML as a last resort. Read the component README for the correct version and inputs.

            ## Phase 2 — Apply, lint, and open a draft MR

            Create branch `duo-agent-platform/improve-ci` from `%{default_branch}`. Apply targeted, low-risk improvements only — do not restructure the entire pipeline. Add inline comments for non-obvious changes.

            Validate before committing:
            ```
            glab ci lint .gitlab-ci.yml
            ```

            Make a single atomic commit, then open a draft MR:
            ```
            glab mr create --draft --title "Draft: Improve CI configuration" --description "$(cat /tmp/mr-description.md)" --assignee @me
            ```
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
