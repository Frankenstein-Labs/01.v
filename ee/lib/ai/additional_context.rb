# frozen_string_literal: true

module Ai
  module AdditionalContext
    # Constants must be defined before API::CodeSuggestions references them
    MAX_BODY_SIZE = 600_000
    MAX_CONTEXT_TYPE_SIZE = 255

    CODE_SUGGESTIONS_CONTEXT_TYPES = { file: 'file', snippet: 'snippet' }.freeze

    # Unlike Duo Chat, Code Suggestions additional context categories are NOT connected to unit primitives
    # The Code Suggestions unit primitives are `complete_code` and `generate_code`
    # The Code Suggestions additional context categories are simply controlled through Feature Flags
    CODE_SUGGESTIONS_CONTEXT_CATEGORIES = [
      :repository_xray,
      :open_tabs,
      :imports
    ].freeze

    # Introducing new types requires adding `include_*_context` unit primitives as well.
    #
    # First, decide whether a unit primitive is part of Duo Pro or Duo Enterprise.
    # Then, follow the examples of `include_*_context` unit primitives:
    # https://gitlab.com/gitlab-org/cloud-connector/gitlab-cloud-connector/-/blob/main/config/unit_primitives/include_issue_context.yml
    # To add new unit primitive, please follow the documentation guidance:
    # https://docs.gitlab.com/ee/development/cloud_connector/#register-new-feature-for-self-managed-dedicated-and-gitlabcom-customers
    DUO_CHAT_CONTEXT_CATEGORIES = {
      file: 'file',
      snippet: 'snippet',
      merge_request: 'merge_request',
      issue: 'issue',
      dependency: 'dependency',
      local_git: 'local_git',
      terminal: 'terminal',
      user_rule: 'user_rule',
      repository: 'repository',
      directory: 'directory',
      agent_user_environment: 'agent_user_environment'
    }.freeze
  end
end
