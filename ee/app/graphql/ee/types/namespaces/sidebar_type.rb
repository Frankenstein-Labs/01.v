# frozen_string_literal: true

module EE
  module Types
    module Namespaces
      module SidebarType
        extend ActiveSupport::Concern

        prepended do
          field :open_epics_count,
            GraphQL::Types::Int,
            null: true,
            description: 'Number of open epics of the namespace.'
        end

        def open_epics_count
          return unless namespace.is_a?(Group)

          ::Groups::EpicsCountService.new(namespace, context[:current_user]).count
        end
      end
    end
  end
end
