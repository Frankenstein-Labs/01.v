# frozen_string_literal: true

module Mutations
  module Security
    module Attributes
      class BulkUpdate < BaseMutation
        graphql_name 'BulkUpdateSecurityAttributes'

        authorize :admin_security_attributes

        MAX_ITEMS = 100
        MAX_ATTRIBUTES = 20

        argument :items, [GraphQL::Types::ID],
          required: true,
          description: 'Global IDs of groups and projects to update.',
          prepare: ->(global_ids, _ctx) {
            if global_ids.size > MAX_ITEMS
              raise Gitlab::Graphql::Errors::ArgumentError, "Too many items (maximum: #{MAX_ITEMS})"
            end

            GitlabSchema.parse_gids(global_ids, expected_type: [Group, Project])
          }

        argument :attributes, [::Types::GlobalIDType[::Security::Attribute]],
          required: true,
          description: 'Global IDs of security attributes to apply.'

        argument :mode, Types::Security::Attributes::BulkUpdateModeEnum,
          required: true,
          description: 'Update mode: add, remove, or replace attributes.'

        field :errors, [GraphQL::Types::String],
          null: false,
          description: 'Errors encountered while initiating the bulk update operation.'

        def resolve(items:, attributes:, mode:)
          validate_arguments!(items, attributes)

          grouped_items = items.group_by { |gid| gid.model_class.name }
          group_ids = grouped_items.fetch('Group', []).map { |item| item.model_id.to_i }
          project_ids = grouped_items.fetch('Project', []).map { |item| item.model_id.to_i }

          result = ::Security::Attributes::BulkUpdateService.new(
            group_ids: group_ids,
            project_ids: project_ids,
            attribute_ids: validate_and_extract_attribute_ids(attributes),
            mode: mode,
            current_user: current_user
          ).execute

          {
            errors: result.success? ? [] : [result.message]
          }
        rescue Gitlab::Access::AccessDeniedError
          raise_resource_not_available_error!
        end

        private

        def validate_arguments!(items, attributes)
          raise Gitlab::Graphql::Errors::ArgumentError, 'Items cannot be empty' if items.empty?
          raise Gitlab::Graphql::Errors::ArgumentError, 'Attributes cannot be empty' if attributes.empty?

          return unless attributes.size > MAX_ATTRIBUTES

          raise Gitlab::Graphql::Errors::ArgumentError, "Too many attributes (maximum: #{MAX_ATTRIBUTES})"
        end

        def validate_and_extract_attribute_ids(attribute_gids)
          attribute_gids.map do |gid|
            attribute = authorized_find!(id: GitlabSchema.parse_gid(gid, expected_type: ::Security::Attribute))

            raise_resource_not_available_error! if attribute.deleted?

            attribute.id
          end
        end
      end
    end
  end
end
