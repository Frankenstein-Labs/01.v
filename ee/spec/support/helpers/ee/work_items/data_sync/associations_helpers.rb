# frozen_string_literal: true

module EE
  module WorkItems
    module DataSync
      module AssociationsHelpers
        BASE_ASSOCIATIONS = {
          base_associations: [
            :synced_epic, :sync_object
          ]
        }.freeze

        WIDGETS_ASSOCIATIONS = {
          agent_plan: [:agent_plan],
          ai_session: [:duo_workflows, :duo_workflow_links, :linked_duo_workflows],
          description: [:own_description_versions],
          hierarchy: [:epic, :epic_issue],
          labels: [:own_resource_label_events],
          notes: [:own_notes],
          notifications: [:own_subscriptions],
          color: [:color],
          custom_fields: [
            :text_field_values, :number_field_values, :date_field_values, :select_field_values
          ],
          health_status: [],
          iteration: [:iteration, :resource_iteration_events],
          progress: [:progress],
          requirement_legacy: [:requirement],
          test_reports: [:test_reports],
          weight: [:resource_weight_events],
          status: [:current_status]
        }.freeze

        NON_WIDGETS_ASSOCIATIONS = {
          related_vulnerabilities: [:vulnerability_links, :related_vulnerabilities],
          tbd: [
            :own_events, :issue_stage_events, :own_resource_state_events, :feature_flags, :feature_flag_issues,
            :observability_metrics, :observability_logs, :observability_traces, :metric_images,
            :status_page_published_incident, :issuable_sla, :pending_escalations, :issuable_resource_links
          ]
        }.freeze

        def base_associations
          super.merge(BASE_ASSOCIATIONS) { |_key, old_value, new_value| old_value + new_value }
        end

        def widgets_associations
          super.merge(WIDGETS_ASSOCIATIONS) { |_key, old_value, new_value| old_value + new_value }
        end

        def non_widgets_associations
          super.merge(NON_WIDGETS_ASSOCIATIONS) { |_key, old_value, new_value| old_value + new_value }
        end
      end
    end
  end
end
