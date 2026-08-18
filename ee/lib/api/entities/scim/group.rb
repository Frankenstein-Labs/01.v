# frozen_string_literal: true

module API
  module Entities
    module Scim
      class Group < Grape::Entity
        expose :schemas
        expose :id do |group, _options|
          group.scim_group_uid
        end
        expose :display_name, as: :displayName do |group, _options|
          group.saml_group_name
        end
        expose :members, unless: ->(_, opts) { opts[:excluded_attributes]&.include?('members') }
        expose :meta do
          expose :resource_type, as: :resourceType
        end

        private

        DEFAULT_SCHEMA = 'urn:ietf:params:scim:schemas:core:2.0:Group'

        def schemas
          [DEFAULT_SCHEMA]
        end

        # Members are preloaded by the API endpoint and passed in via the `scim_members`
        # option as { scim_group_uid => [{ extern_uid:, name: }, ...] }, keeping the query
        # out of the serializer and avoiding N+1 when a page of groups is rendered.
        def members
          members_by_uid = options[:scim_members] || {}

          (members_by_uid[object.scim_group_uid] || []).map do |member|
            { value: member[:extern_uid], display: member[:name], type: 'User' }
          end
        end

        def resource_type
          'Group'
        end
      end
    end
  end
end
