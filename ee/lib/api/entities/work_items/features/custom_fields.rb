# frozen_string_literal: true

module API
  module Entities
    module WorkItems
      module Features
        class CustomFields < Grape::Entity
          class SelectOption < Grape::Entity
            expose :id, documentation: { type: 'Integer', example: 1 } # rubocop:disable API/EntityExposureGrowth -- Pre-existing exposure retained when adding entity to high-impact baseline
            expose :value, documentation: { type: 'String', example: 'High' } # rubocop:disable API/EntityExposureGrowth -- Pre-existing exposure retained when adding entity to high-impact baseline
          end

          class CustomField < Grape::Entity
            expose :id, documentation: { type: 'Integer', example: 1 } # rubocop:disable API/EntityExposureGrowth -- Pre-existing exposure retained when adding entity to high-impact baseline
            expose :name, documentation: { type: 'String', example: 'Priority' }
            expose :field_type,
              documentation: {
                type: 'String', example: 'single_select', values: ::Issuables::CustomField.field_types.keys
              }
            expose :active, documentation: { type: 'Boolean', example: true } do |custom_field, _options|
              custom_field.active?
            end
            expose :created_at, documentation: { type: 'DateTime', example: '2024-02-12T09:45:00Z' }
            expose :updated_at, documentation: { type: 'DateTime', example: '2024-02-12T09:45:00Z' }
            expose :created_by, using: ::API::Entities::UserBasic,
              documentation: { type: 'Entities::UserBasic' }, expose_nil: true
            expose :updated_by, using: ::API::Entities::UserBasic,
              documentation: { type: 'Entities::UserBasic' }, expose_nil: true
            expose :select_options,
              using: ::API::Entities::WorkItems::Features::CustomFields::SelectOption,
              documentation: { type: 'Entities::WorkItems::Features::CustomFields::SelectOption', is_array: true },
              if: ->(custom_field, _) { custom_field.field_type_select? }
            expose :work_item_types,
              using: ::API::Entities::WorkItems::Type,
              documentation: { type: 'Entities::WorkItems::Type', is_array: true }
          end

          class CustomFieldValue < Grape::Entity
            expose :custom_field,
              using: ::API::Entities::WorkItems::Features::CustomFields::CustomField,
              documentation: { type: 'Entities::WorkItems::Features::CustomFields::CustomField' }

            expose :value, # rubocop:disable API/EntityExposureGrowth -- Pre-existing exposure retained when adding entity to high-impact baseline
              documentation: { type: 'String', example: 'In progress' },
              if: ->(field_value, _) { !field_value[:custom_field].field_type_select? } do |field_value|
                value = field_value[:value]
                # Number values are stored as a numeric column (BigDecimal) which would otherwise
                # serialize to a JSON string. Coerce to Float to keep parity with the GraphQL API.
                field_value[:custom_field].field_type_number? && value ? value.to_f : value
              end

            expose :selected_options,
              using: ::API::Entities::WorkItems::Features::CustomFields::SelectOption,
              documentation: { type: 'Entities::WorkItems::Features::CustomFields::SelectOption', is_array: true },
              if: ->(field_value, _) { field_value[:custom_field].field_type_select? } do |field_value|
                field_value[:value]
              end
          end

          expose :custom_field_values,
            using: ::API::Entities::WorkItems::Features::CustomFields::CustomFieldValue,
            documentation: {
              type: 'Entities::WorkItems::Features::CustomFields::CustomFieldValue', is_array: true
            },
            expose_nil: true do |widget, _options|
              widget.custom_field_values
            end
        end
      end
    end
  end
end
