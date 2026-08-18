# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      class ItemConsumerType < ::Types::BaseObject
        graphql_name 'AiCatalogItemConsumer'
        description 'An AI catalog item configuration'
        authorize :read_ai_catalog_item_consumer

        connection_type_class ::Types::CountableConnectionType

        expose_permissions ::Types::PermissionTypes::Ai::Catalog::ItemConsumer

        PATH_HELPERS = {
          group: {
            agent: ->(container, id) { helpers.group_automate_agent_path(container, id: id) },
            third_party_flow: ->(container, id) { helpers.group_automate_agent_path(container, id: id) },
            flow: ->(container, id) { helpers.group_automate_flow_path(container, id: id) }
          },
          project: {
            agent: ->(container, id) { helpers.project_automate_agent_path(container, id: id) },
            third_party_flow: ->(container, id) { helpers.project_automate_agent_path(container, id: id) },
            flow: ->(container, id) { helpers.project_automate_flow_path(container, id: id) }
          }
        }.freeze

        field :enabled, GraphQL::Types::Boolean,
          null: true,
          description: 'Indicates if the configuration item is enabled.'
        field :flow_trigger, ::Types::Ai::FlowTriggerType,
          null: true,
          description: 'Trigger associated with the configured catalog item.'
        field :group, ::Types::GroupType,
          null: true,
          description: 'Group in which the catalog item is configured.'
        field :id, GraphQL::Types::ID,
          null: false,
          description: 'ID of the configuration item.'
        field :item, ::Types::Ai::Catalog::ItemInterface,
          null: true,
          description: 'Configuration catalog item.'
        field :organization, ::Types::Organizations::OrganizationType,
          null: true,
          description: 'Organization in which the catalog item is configured.'
        field :parent_item_consumer, ::Types::Ai::Catalog::ItemConsumerType,
          null: true,
          description: 'Parent item consumer associated with the configured catalog item.'
        field :pinned_item_version, ::Types::Ai::Catalog::VersionInterface,
          null: true,
          description: 'Resolved item version according to the `pinnedVersionPrefix`.' \
            'This field can only be resolved for 20 AiCatalogItemConsumers in any single request.' do
          extension(::Gitlab::Graphql::Limit::FieldCallCount, limit: 20)
        end
        field :pinned_version_prefix, ::Types::Ai::Catalog::PinnedVersionType, # rubocop:disable GraphQL/ExtractType -- Not sensible to create a "pinned" type
          null: true,
          description: 'Version the item is pinned to, in the format `n.n.n`.'
        field :project, ::Types::ProjectType,
          null: true,
          description: 'Project in which the catalog item is configured.'
        field :service_account, ::Types::UserType,
          null: true,
          description: 'Service account associated with the item consumer.'
        field :web_path, GraphQL::Types::String,
          null: true,
          description: 'Web path of the catalog item consumer configuration page.'

        def self.helpers
          ::Gitlab::Routing.url_helpers
        end

        def item
          ::Gitlab::Graphql::Loaders::BatchModelLoader.new(::Ai::Catalog::Item, object.ai_catalog_item_id).find
        end

        def parent_item_consumer
          ::Gitlab::Graphql::Loaders::BatchModelLoader.new(::Ai::Catalog::ItemConsumer, object.parent_item_consumer_id)
            .find
        end

        def pinned_item_version
          object.item&.resolve_version(object.pinned_version_prefix)
        end

        def service_account
          ::Gitlab::Graphql::Loaders::BatchModelLoader.new(User, object.service_account_id).find
        end

        def flow_trigger
          BatchLoader::GraphQL.for(object.id).batch do |item_consumer_ids, loader|
            ::Ai::FlowTrigger.by_item_consumer_ids(item_consumer_ids).each do |trigger|
              loader.call(trigger.ai_catalog_item_consumer_id, trigger)
            end
          end
        end

        def web_path
          Gitlab::Graphql::Lazy.with_value(item) { |resolved_item| item_consumer_path(resolved_item) if resolved_item }
        end

        private

        def item_consumer_path(item)
          container_type, container = if object.group
                                        [:group, object.group]
                                      elsif object.project
                                        [:project, object.project]
                                      end

          return unless container_type

          path_helper = PATH_HELPERS.dig(container_type, item.item_type.to_sym)
          return unless path_helper

          path_helper.call(container, item.id)
        end
      end
    end
  end
end
