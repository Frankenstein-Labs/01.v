# frozen_string_literal: true

module API
  module Entities
    class GroupPushRule < Grape::Entity
      expose :id, documentation: { type: 'Integer', format: 'int64', example: 2 }
      expose :created_at, documentation: { type: 'DateTime', example: '2020-08-31T15:53:00.073Z' }
      expose :commit_message_regex, documentation: { type: 'String', example: '[a-zA-Z]' }
      expose :commit_message_negative_regex, documentation: { type: 'String', example: '[x+]' }
      expose :branch_name_regex, documentation: { type: 'String', example: '[a-z]' }
      expose :author_email_regex, documentation: { type: 'String', example: '^[A-Za-z0-9.]+@gitlab.com$' }
      expose :file_name_regex, documentation: { type: 'String', example: '(exe)$' }
      expose :deny_delete_tag, documentation: { type: 'Boolean' }
      expose :member_check, documentation: { type: 'Boolean', example: true }
      expose :prevent_secrets, documentation: { type: 'Boolean' }
      expose :max_file_size, documentation: { type: 'Integer', example: 100 }
      expose :commit_committer_check,
        if: ->(push_rule) { push_rule.available?(:commit_committer_check) },
        documentation: { type: 'Boolean' }
      expose :commit_committer_name_check,
        if: ->(push_rule) { push_rule.available?(:commit_committer_name_check) },
        documentation: { type: 'Boolean' }
      expose :reject_unsigned_commits,
        if: ->(push_rule) { push_rule.available?(:reject_unsigned_commits) },
        documentation: { type: 'Boolean' }
      expose :reject_non_dco_commits,
        if: ->(push_rule) { push_rule.available?(:reject_non_dco_commits) },
        documentation: { type: 'Boolean' }
    end
  end
end
