# frozen_string_literal: true

module EE
  module API
    module Helpers
      module WorkItems
        module CreateParams
          extend ActiveSupport::Concern
          extend ::Grape::API::Helpers

          prepended do
            params :work_item_create_features_ee do
              optional :color, type: Hash, desc: 'Input for color feature.' do
                requires :color, type: String,
                  desc: 'Color of the work item as a hex code (for example, "#e24329").'
              end

              optional :health_status, type: Hash, desc: 'Input for health status widget.' do
                optional :health_status, type: String,
                  values: ::Issue.health_statuses.keys,
                  desc: 'Health status. Values: on_track, needs_attention, or at_risk.'
              end

              optional :iteration, type: Hash, desc: 'Input for iteration widget.' do
                optional :iteration_id, type: Integer,
                  desc: 'ID of the iteration to assign to the work item. Null to unset.'
              end

              optional :weight, type: Hash, desc: 'Input for weight widget.' do
                optional :weight, type: Integer,
                  desc: 'Weight of the work item. Null to unset.'
              end

              optional :status, type: Hash, desc: 'Input for status widget.' do
                optional :status_id, type: Integer,
                  desc: 'ID of the status to assign to the work item. The namespace determines whether this ' \
                    'resolves to a custom status or a system-defined status, as the two are mutually exclusive ' \
                    'per namespace.'
              end

              optional :custom_fields, type: Array, desc: 'Input for custom fields widget.' do
                optional :custom_field_id, type: Integer,
                  desc: 'Numeric ID of the custom field.'
                optional :text_value, type: String,
                  desc: 'Value for custom fields with text type.'
                optional :number_value, type: Float,
                  desc: 'Value for custom fields with number type.'
                optional :date_value, type: Date,
                  desc: 'Value for custom fields with date type.'
                optional :selected_option_ids, type: Array[Integer],
                  desc: 'Numeric IDs of the selected options for custom fields with select type.'
              end
            end
          end
        end
      end
    end
  end
end
