# frozen_string_literal: true

module EE
  module API
    module Helpers
      module ProtectedTagsHelpers
        extend ActiveSupport::Concern

        prepended do
          params :optional_params_ee do
            optional :allowed_to_create, type: Array[JSON],
              desc: 'Array of users, groups, deploy keys, or access levels allowed to create protected branches' do
              # rubocop:disable API/AccessLevelStringType -- Introduced before the cop
              optional :access_level, type: Integer, desc: 'ID of an access level',
                values: ::ProtectedTag::CreateAccessLevel.allowed_access_levels
              # rubocop:enable API/AccessLevelStringType
              optional :user_id, type: Integer, desc: 'ID of a user'
              optional :group_id, type: Integer, desc: 'ID of a group'
              optional :deploy_key_id, type: Integer, desc: 'ID of a deploy key'
            end
          end
        end
      end
    end
  end
end
