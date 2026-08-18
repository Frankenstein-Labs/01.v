# frozen_string_literal: true

module EE
  module API
    module Helpers
      module ProtectedBranchesHelpers
        extend ActiveSupport::Concern

        prepended do
          params :shared_params do
            optional :user_id, type: Integer, desc: 'ID of a user', documentation: { example: 1 }
            optional :group_id, type: Integer, desc: 'ID of a group', documentation: { example: 1 }
            optional :member_role_id, type: Integer, desc: 'ID of a custom member role', documentation: { example: 1, format: 'int64' }
            optional :id, type: Integer, desc: 'ID of a project', documentation: { example: 40 }
            optional :_destroy, type: Grape::API::Boolean, desc: 'Delete the object when true'
          end

          params :optional_params_ee do
            # rubocop:disable API/AccessLevelStringType -- Introduced before the cop
            optional :unprotect_access_level,
              type: Integer,
              values: ::ProtectedBranch::UnprotectAccessLevel.allowed_access_levels,
              desc: 'Access levels allowed to unprotect (defaults: `40`, maintainer access level)'
            # rubocop:enable API/AccessLevelStringType

            optional :allowed_to_push, type: Array[JSON], desc: 'Array of users, groups, deploy keys, or access levels allowed to push to protected branches' do
              optional :access_level, type: Integer, desc: 'Access level allowed to push', values: ::ProtectedBranch::PushAccessLevel.allowed_access_levels # rubocop:disable API/AccessLevelStringType -- Introduced before the cop

              optional :deploy_key_id, type: Integer, desc: 'Deploy key allowed to push', documentation: { example: 1 }
              use :shared_params
            end

            optional :allowed_to_merge, type: Array[JSON], desc: 'Array of users, groups, or access levels allowed to merge protected branches' do
              optional :access_level, type: Integer, desc: 'Access level allowed to merge', values: ::ProtectedBranch::MergeAccessLevel.allowed_access_levels # rubocop:disable API/AccessLevelStringType -- Introduced before the cop

              use :shared_params
            end

            optional :allowed_to_unprotect, type: Array[JSON], desc: 'Array of users, groups, or access levels allowed to unprotect protected branches' do
              optional :access_level, type: Integer, desc: 'Access level allowed to unprotect', values: ::ProtectedBranch::UnprotectAccessLevel.allowed_access_levels # rubocop:disable API/AccessLevelStringType -- Introduced before the cop

              use :shared_params
            end

            optional :code_owner_approval_required, type: Grape::API::Boolean, desc: 'Prevent pushes to this branch if it matches an item in CODEOWNERS'
          end
        end
      end
    end
  end
end
