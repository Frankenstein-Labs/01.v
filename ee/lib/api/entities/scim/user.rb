# frozen_string_literal: true

module API
  module Entities
    module Scim
      class User < Grape::Entity
        expose :schemas
        expose :extern_uid, as: :id
        expose :active
        expose :email_user, as: :emails, using: ::API::Entities::Scim::Emails

        expose :name, using: ::API::Entities::Scim::UserName do |identity, _options|
          identity.user
        end

        expose :meta do
          expose :resource_type, as: :resourceType
        end
        expose :username, as: :userName do |identity, _options|
          identity.user.username
        end

        # The groups attribute is only meaningful for the instance-level SCIM API
        # since the group-level API does not have a /Groups resource.
        # It should only appear when a caller passes the scim_groups option
        expose :groups, if: ->(_, opts) { opts[:scim_groups] }

        private

        DEFAULT_SCHEMA = 'urn:ietf:params:scim:schemas:core:2.0:User'

        def schemas
          [DEFAULT_SCHEMA]
        end

        def active
          object_active = object.try(:active)

          return true if object_active.nil?

          object_active
        end

        def email_user
          [object.user]
        end

        def groups
          groups_by_user_id = options[:scim_groups]

          (groups_by_user_id[object.user_id] || []).map do |group|
            { value: group[:scim_group_uid], display: group[:name], type: 'direct' }
          end
        end

        def resource_type
          'User'
        end
      end
    end
  end
end
