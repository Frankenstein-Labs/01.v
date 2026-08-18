# frozen_string_literal: true

module Ai
  module Catalog
    module Onboarding
      class Initializer
        AGENTS_MD_PATHS = %w[AGENTS.md .ai/AGENTS.md].freeze
        GITLAB_CI_YML_PATH = '.gitlab-ci.yml'
        AGENT_CONFIG_PATH = '.gitlab/duo/agent-config.yml'
        MR_REVIEW_INSTRUCTIONS_PATH = '.gitlab/duo/mr-review-instructions.yaml'
        CHAT_RULES_PATH = '.gitlab/duo/chat-rules.md'

        attr_reader :event_type, :display_name, :description, :target_file

        def self.all
          [
            new(
              event_type: 'init_project_context',
              display_name: s_('Onboarding|Initialize project context'),
              description: s_('Onboarding|Analyze the repository and create an AGENTS.md file so ' \
                'GitLab Duo Agent Platform understands your codebase.'),
              target_file: 'AGENTS.md',
              applicability_paths: AGENTS_MD_PATHS
            ),
            new(
              event_type: 'improve_ci',
              display_name: s_('Onboarding|Improve CI setup'),
              description: s_('Onboarding|Analyze your .gitlab-ci.yml and get improvement suggestions ' \
                'in a draft merge request.'),
              target_file: GITLAB_CI_YML_PATH,
              applicability_paths: [GITLAB_CI_YML_PATH],
              requires_file_present: true
            ),
            new(
              event_type: 'init_execution_env',
              display_name: s_('Onboarding|Initialize execution environment'),
              description: s_('Onboarding|Create a .gitlab/duo/agent-config.yml file so CI-launched ' \
                'flows run in a container that matches your tech stack.'),
              target_file: AGENT_CONFIG_PATH,
              applicability_paths: [AGENT_CONFIG_PATH]
            ),
            new(
              event_type: 'init_mr_review_instructions',
              display_name: s_('Onboarding|Initialize code review instructions'),
              description: s_('Onboarding|Analyze the repository and create a ' \
                '.gitlab/duo/mr-review-instructions.yaml file so the Code Review flow ' \
                'enforces your project conventions.'),
              target_file: MR_REVIEW_INSTRUCTIONS_PATH,
              applicability_paths: [MR_REVIEW_INSTRUCTIONS_PATH]
            ),
            new(
              event_type: 'init_codeowners',
              display_name: s_('Onboarding|Protect agent files with Code Owners'),
              description: s_('Onboarding|Add a CODEOWNERS rule so the files Duo reads as ' \
                'instructions (AGENTS.md, .gitlab/duo/, skills/) require code-owner review ' \
                'before changes merge.'),
              target_file: 'CODEOWNERS',
              code_owner_paths: %w[AGENTS.md .gitlab/duo/agent-config.yml skills/SKILL.md]
            ),
            new(
              event_type: 'init_chat_rules',
              display_name: s_('Onboarding|Initialize Chat custom rules'),
              description: s_('Onboarding|Analyze the repository and create a ' \
                '.gitlab/duo/chat-rules.md file with rules tuned for interactive ' \
                'GitLab Duo Chat conversations.'),
              target_file: CHAT_RULES_PATH,
              applicability_paths: [CHAT_RULES_PATH]
            )
          ]
        end

        def self.find(event_type)
          all.find { |initializer| initializer.event_type == event_type.to_s }
        end

        def initialize(
          event_type:, display_name:, description:, target_file:, applicability_paths: [],
          requires_file_present: false, code_owner_paths: nil)
          @event_type = event_type
          @display_name = display_name
          @description = description
          @target_file = target_file
          @applicability_paths = applicability_paths
          @requires_file_present = requires_file_present
          @code_owner_paths = code_owner_paths
        end

        def applicable_for?(project)
          @requires_file_present ? file_present?(project) : !file_present?(project)
        end

        def skip_reason(project)
          return if applicable_for?(project)

          @requires_file_present ? :prerequisite_missing : :already_present
        end

        private

        def file_present?(project)
          return false unless project.repository.exists?

          ref = project.default_branch_or_main

          return code_owner_paths_covered?(project, ref) if @code_owner_paths

          @applicability_paths.any? do |path|
            !project.repository.blob_at(ref, path).nil?
          end
        end

        def code_owner_paths_covered?(project, ref)
          @code_owner_paths.all? do |path|
            ::Gitlab::CodeOwners::Loader.new(project, ref, [path]).members.present?
          end
        end
      end
    end
  end
end
