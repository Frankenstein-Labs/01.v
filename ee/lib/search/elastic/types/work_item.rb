# frozen_string_literal: true

module Search
  module Elastic
    module Types
      class WorkItem
        class << self
          def index_name
            Search::Elastic::References::WorkItem.index
          end

          def target
            ::WorkItem
          end

          def mappings
            {
              dynamic: 'strict',
              properties: base_mappings
            }
          end

          def settings
            ::Elastic::Latest::Config.settings.to_hash.deep_merge(
              index: ::Elastic::Latest::Config.separate_index_specific_settings(index_name)
            )
          end

          private

          def base_mappings
            {
              type: { type: 'keyword' },
              id: { type: 'long' },
              iid: { type: 'integer' },
              title: { type: 'text', index_options: 'positions', analyzer: :title_analyzer },
              description: { type: 'text', index_options: 'positions', analyzer: :code_analyzer },
              namespace_id: { type: 'long' },
              root_namespace_id: { type: 'long' },
              created_at: { type: 'date' },
              updated_at: { type: 'date' },
              due_date: { type: 'date' },
              state: { type: 'keyword' },
              project_id: { type: 'long' },
              routing: { type: 'text' },
              author_id: { type: 'long' },
              confidential: { type: 'boolean' },
              hidden: { type: 'boolean' },
              archived: { type: 'boolean' },
              assignee_id: { type: 'long' },
              project_visibility_level: { type: 'short' },
              namespace_visibility_level: { type: 'short' },
              issues_access_level: { type: 'short' },
              upvotes: { type: 'integer' },
              traversal_ids: { type: 'keyword' },
              label_ids: { type: 'keyword' },
              hashed_root_namespace_id: { type: 'integer' },
              work_item_type_id: { type: 'long' },
              schema_version: { type: 'short' },
              milestone_title: { type: 'keyword' },
              milestone_id: { type: 'long' },
              milestone_start_date: { type: 'date' },
              milestone_due_date: { type: 'date' },
              milestone_state: { type: 'keyword' },
              closed_at: { type: 'date' },
              weight: { type: 'integer' },
              health_status: { type: 'short' },
              label_names: { type: 'keyword' }
            }
          end
        end
      end
    end
  end
end
