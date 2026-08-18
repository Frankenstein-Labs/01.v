# frozen_string_literal: true

module WorkItems
  module Statuses
    module SystemDefined
      class Lifecycle
        include ActiveRecord::FixedItemsModel::Model
        include GlobalID::Identification
        include WorkItems::Statuses::Lifecycle

        ITEMS = [
          {
            id: 1,
            name: 'Default',
            work_item_base_types: [:issue, :task],
            status_ids: [1, 2, 3, 4, 5],
            default_open_status_id: 1,
            default_closed_status_id: 3,
            default_duplicate_status_id: 5
          }
        ].freeze

        attribute :name, :string
        attribute :work_item_base_types
        attribute :status_ids
        attribute :default_open_status_id, :integer
        attribute :default_closed_status_id, :integer
        attribute :default_duplicate_status_id, :integer

        class << self
          def of_work_item_base_type(base_type)
            all.find { |item| item.for_base_type?(base_type.to_sym) }
          end
        end

        def for_base_type?(base_type)
          work_item_base_types.include?(base_type)
        end

        def work_item_types(namespace = nil)
          ::WorkItems::TypesFramework::Provider.new(namespace).by_base_types(work_item_base_types)
        end

        def statuses
          Status.where(id: status_ids)
        end
        alias_method :ordered_statuses, :statuses

        def has_status_id?(status_id)
          statuses.map(&:id).include?(status_id)
        end

        def default_open_status
          Status.find(default_open_status_id)
        end

        def default_closed_status
          Status.find(default_closed_status_id)
        end

        def default_duplicate_status
          Status.find(default_duplicate_status_id)
        end

        def default_statuses
          [default_open_status, default_closed_status, default_duplicate_status].compact
        end

        def custom?
          false
        end
      end
    end
  end
end
