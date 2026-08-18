# frozen_string_literal: true

module EE
  module Mutations
    module WorkItems
      module BulkUpdate
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          argument :health_status_widget,
            ::Types::WorkItems::Widgets::HealthStatusInputType,
            required: false,
            description: 'Input for health status widget.',
            experiment: { milestone: '18.2' }

          argument :iteration_widget,
            ::Types::WorkItems::Widgets::IterationInputType,
            required: false,
            description: 'Input for iteration widget.',
            experiment: { milestone: '18.2' }

          argument :status_widget,
            ::Types::WorkItems::Widgets::StatusInputType,
            required: false,
            description: 'Input for status widget.',
            experiment: { milestone: '18.3' }
        end

        private

        override :resource_parent!
        def resource_parent!(full_path)
          parent = super
          return parent unless parent.is_a?(::Group)

          unless parent.licensed_feature_available?(:group_bulk_edit)
            raise_resource_not_available_error!(
              _('Group work item bulk edit is a licensed feature not available for this group.')
            )
          end

          parent
        end

        override :find_parent_by_full_path
        def find_parent_by_full_path(full_path, model = ::Namespace)
          namespace = super

          return namespace.owner_entity unless namespace.is_a?(::Namespaces::UserNamespace)

          nil
        end
      end
    end
  end
end
