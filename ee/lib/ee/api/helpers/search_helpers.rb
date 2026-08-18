# frozen_string_literal: true

module EE
  module API
    module Helpers
      module SearchHelpers
        extend ActiveSupport::Concern

        class_methods do
          extend ::Gitlab::Utils::Override

          override :global_search_scopes
          def global_search_scopes
            ['wiki_blobs', 'blobs', 'commits', 'notes', *super]
          end

          override :group_search_scopes
          def group_search_scopes
            ['wiki_blobs', 'blobs', 'commits', 'notes', *super]
          end

          override :search_param_keys
          def search_param_keys
            [*super, :exclude_forks, :fields, :num_context_lines, :regex]
          end

          override :work_item_type_filter_desc
          def work_item_type_filter_desc
            'Filter work items by type. Only applies to work_items scope. ' \
              'Available types: issue, task, epic, incident, test_case, requirement, objective, key_result, ticket.'
          end
        end
      end
    end
  end
end
