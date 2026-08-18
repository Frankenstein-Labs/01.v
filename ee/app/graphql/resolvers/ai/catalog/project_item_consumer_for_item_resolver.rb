# frozen_string_literal: true

module Resolvers
  module Ai
    module Catalog
      class ProjectItemConsumerForItemResolver < BaseResolver
        description 'AI Catalog item configuration for the given item in a project.'

        type ::Types::Ai::Catalog::ItemConsumerType, null: true

        argument :id,
          ::Types::GlobalIDType[::Ai::Catalog::Item],
          required: true,
          description: 'Global ID of the catalog item to return the configuration of.'

        def resolve(id:)
          BatchLoader::GraphQL.for([object, id.model_id.to_i]).batch do |project_item_pairs, loader|
            projects_by_id = project_item_pairs.to_h { |project, _| [project.id, project] }
            keyed_pairs = project_item_pairs.map { |project, item_id| [project.id, item_id] }

            preload_root_ancestor_settings(projects_by_id.values)

            ::Ai::Catalog::ItemConsumer
              .for_container_item_pairs(:project, keyed_pairs)
              .with_items
              .find_each do |consumer|
                # Prevent consumer.project from triggering an N+1 query
                consumer.project = projects_by_id[consumer.project_id] if projects_by_id.key?(consumer.project_id)
                loader.call([projects_by_id[consumer.project_id], consumer.ai_catalog_item_id], consumer)
              end
          end
        end

        private

        def preload_root_ancestor_settings(projects)
          root_ancestors = projects.filter_map(&:root_ancestor).uniq

          ActiveRecord::Associations::Preloader.new(
            records: root_ancestors,
            associations: [:namespace_settings, :ai_settings]
          ).call
        end
      end
    end
  end
end
