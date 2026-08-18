# frozen_string_literal: true

module WorkItems
  module Statuses
    module SystemDefined
      class Status
        include ActiveRecord::FixedItemsModel::Model
        include GlobalID::Identification
        include WorkItems::Statuses::Status
        include ::WorkItems::ConfigurableStatus

        ITEMS = [
          {
            id: 1,
            name: 'To do',
            color: '#737278',
            category: :to_do
          },
          {
            id: 2,
            name: 'In progress',
            color: '#1f75cb',
            category: :in_progress
          },
          {
            id: 3,
            name: 'Done',
            color: '#108548',
            category: :done
          },
          {
            id: 4,
            name: "Won't do",
            color: '#DD2B0E',
            category: :canceled
          },
          {
            id: 5,
            name: 'Duplicate',
            color: '#DD2B0E',
            category: :canceled,
            position: 10
          }
        ].freeze

        attribute :name, :string
        attribute :color, :string
        attribute :category
        # For custom statuses position will be on the join model between
        # custom lifecycle and custom status to allow modification per lifecycle.
        # We don't plan to change the position of the status for system defined lifecycles.
        attribute :position, :integer, default: 0

        class << self
          def find_by_name(status_name, partial_match: false)
            if partial_match
              normalized_name = status_name.downcase.strip
              all.select { |status| status.name.downcase.strip.include?(normalized_name) }
            else
              all.find { |status| status.matches_name?(status_name) }
            end
          end

          def sort_order_by_id
            all.each_with_object({}) do |status, hash|
              hash[status.id] = WorkItems::Statuses::SharedConstants::CATEGORIES[status.category]
            end
          end
        end

        def allowed_for_work_item?(work_item)
          return false unless work_item.present?

          lifecycle = Lifecycle.of_work_item_base_type(work_item.work_item_type.base_type.to_sym)
          return false unless lifecycle.present?

          # Doesn't rely on widget availability but on the list of supported types.
          # Widget availability controls which data is exposed and whether system notes are created.
          lifecycle.has_status_id?(id)
        end

        def converted_status_in_namespace(namespace)
          return self if namespace.converted_statuses.blank?

          namespace.converted_statuses.find do |s|
            s.converted_from_system_defined_status_identifier == id
          end
        end

        def description
          nil
        end

        def matches_name?(other_name)
          name.casecmp(other_name) == 0
        end

        def in_use_in_namespace?(namespace, work_item_type_ids: nil)
          relation = WorkItem.joins(:namespace)
            .where(namespace_id: namespace.self_and_descendant_ids(skope: Namespace))
            .with_system_defined_status(self)

          relation = relation.where(work_item_type_id: work_item_type_ids) if work_item_type_ids

          relation.exists?
        end
      end
    end
  end
end
