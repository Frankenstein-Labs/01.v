# frozen_string_literal: true

module EE
  module API
    module Helpers
      module WorkItems
        module ListParams
          extend ActiveSupport::Concern

          prepended do
            params :work_items_filter_params_ee do
              optional :iteration_id, type: Integer,
                desc: 'Filter by iteration ID.'
              optional :iteration_wildcard_id, type: String,
                values: %w[None Any Current],
                desc: 'Filter by iteration wildcard. Values: None, Any, or Current.'
              mutually_exclusive :iteration_id, :iteration_wildcard_id

              optional :iteration_cadence_id, type: Array[Integer],
                desc: 'Filter by iteration cadence IDs.',
                coerce_with: ::API::Validations::Types::CommaSeparatedToIntegerArray.coerce

              optional :health_status_filter, type: String,
                values: %w[none any on_track needs_attention at_risk],
                desc: 'Filter by health status. Values: none, any, on_track, needs_attention, or at_risk.'

              optional :weight, type: String,
                desc: 'Filter by weight. Supports specific weight values, "none", and "any".'
              optional :weight_wildcard_id, type: String,
                values: %w[None Any],
                desc: 'Filter by weight wildcard. Values: None or Any.'
              mutually_exclusive :weight, :weight_wildcard_id

              optional :custom_field, type: Array,
                desc: 'Filter by custom fields (select type only).' do
                optional :custom_field_id, type: Integer,
                  desc: 'ID of the custom field.'
                optional :custom_field_name, type: String,
                  desc: 'Name of the custom field.'
                mutually_exclusive :custom_field_id, :custom_field_name
                optional :selected_option_ids, type: Array[Integer],
                  desc: 'IDs of the selected options.',
                  coerce_with: ::API::Validations::Types::CommaSeparatedToIntegerArray.coerce
                optional :selected_option_values, type: Array[String],
                  desc: 'Values of the selected options.',
                  coerce_with: ::API::Validations::Types::CommaSeparatedToArray.coerce
                mutually_exclusive :selected_option_ids, :selected_option_values
              end

              optional :status, type: Hash,
                desc: 'Filter by work item status.' do
                optional :id, type: Integer,
                  desc: 'ID of the status to filter by. The namespace determines whether this ' \
                    'resolves to a custom status or a system-defined status, as the two are ' \
                    'mutually exclusive per namespace.'
                optional :name, type: String,
                  desc: 'Name of the status.'
                mutually_exclusive :id, :name
              end

              optional :verification_status_widget, type: Hash,
                desc: 'Filter by verification status.' do
                optional :verification_status, type: String,
                  values: %w[passed failed missing],
                  desc: 'Verification status. Values: passed, failed, or missing.'
              end
            end

            params :work_items_not_filter_params_ee do
              optional :iteration_id, type: Integer,
                desc: 'Exclude work items in this iteration.'
              optional :iteration_wildcard_id, type: String,
                values: %w[None Any Current],
                desc: 'Exclude by iteration wildcard. Values: None, Any, or Current.'
              mutually_exclusive :iteration_id, :iteration_wildcard_id

              optional :health_status_filter, type: Array[String],
                values: ::Issue.health_statuses.keys,
                desc: 'Exclude work items with these health statuses.',
                coerce_with: ::API::Validations::Types::CommaSeparatedToArray.coerce

              optional :weight, type: String,
                desc: 'Exclude work items with this weight.'
            end
          end
        end
      end
    end
  end
end
