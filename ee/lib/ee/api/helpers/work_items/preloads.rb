# frozen_string_literal: true

module EE
  module API
    module Helpers
      module WorkItems
        module Preloads
          extend ::Gitlab::Utils::Override

          EE_FEATURE_PRELOADS = {
            agent_plan: [:agent_plan],
            health_status: [],
            color: [:color],
            progress: [:progress],
            iteration: [{ iteration: :group }],
            weight: [:weights_source],
            custom_fields: [
              :namespace,
              :text_field_values,
              :number_field_values,
              :date_field_values,
              { select_field_values: :custom_field_select_option }
            ],
            start_and_due_date: [
              {
                dates_source: {
                  start_date_sourcing_work_item: [{ namespace: :route }],
                  due_date_sourcing_work_item: [{ namespace: :route }],
                  start_date_sourcing_milestone: [:group],
                  due_date_sourcing_milestone: [:group]
                }
              }
            ]
          }.freeze

          override :preload_associations_for
          def preload_associations_for(field_keys, feature_keys, resource_parent)
            preloads = super

            ee_preloads = feature_keys.flat_map do |feature|
              EE_FEATURE_PRELOADS.fetch(feature, [])
            end

            (preloads + ee_preloads).uniq
          end

          override :count_preloads_for
          def count_preloads_for(work_items, field_keys, feature_keys)
            preloads = super
            preloads[:blocked_by_counts] = preload_blocked_by_counts(work_items) if feature_keys.include?(:linked_items)
            preloads
          end

          private

          def preload_blocked_by_counts(work_items)
            return {} if work_items.empty?

            ::WorkItems::RelatedWorkItemLink
              .blocked_issuables_for_collection(work_items.map(&:id))
              .each_with_object({}) { |row, hash| hash[row.blocked_issue_id] = row.count.to_i }
          end
        end
      end
    end
  end
end
