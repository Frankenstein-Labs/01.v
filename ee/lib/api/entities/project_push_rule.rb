# frozen_string_literal: true

module API
  module Entities
    class ProjectPushRule < Grape::Entity
      extend ::API::Entities::EntityHelpers

      expose :id, documentation: { type: 'Integer', format: 'int64', example: 2 }
      expose :project_id, documentation: { type: 'Integer', format: 'int64', example: 3 }
      expose :created_at, documentation: { type: 'DateTime', example: '2020-08-31T15:53:00.073Z' }
      expose :commit_message_regex, documentation: { type: 'String', example: 'Fixed \d+\..*' }
      expose :commit_message_negative_regex, documentation: { type: 'String', example: 'ssh\:\/\/' }
      expose :branch_name_regex, documentation: { type: 'String', example: '(feature|hotfix)\/.*' }
      expose :deny_delete_tag, documentation: { type: 'Boolean', example: true }
      expose :member_check, documentation: { type: 'Boolean', example: true }
      expose :prevent_secrets, documentation: { type: 'Boolean', example: true }
      expose :author_email_regex, documentation: { type: 'String', example: '@my-company.com$' }
      expose :file_name_regex, documentation: { type: 'String', example: '(jar|exe)$' }
      expose :max_file_size, documentation: { type: 'Integer', example: 1024 }
      expose_restricted :commit_committer_check, documentation: { type: 'Boolean', example: true }, &:project
      expose_restricted :commit_committer_name_check, documentation: { type: 'Boolean', example: true }, &:project
      expose_restricted :reject_unsigned_commits, documentation: { type: 'Boolean', example: true }, &:project
      expose_restricted :reject_non_dco_commits, documentation: { type: 'Boolean', example: true }, &:project
    end
  end
end
