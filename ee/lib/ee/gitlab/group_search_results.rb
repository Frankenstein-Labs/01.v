# frozen_string_literal: true

module EE
  module Gitlab
    module GroupSearchResults
      extend ::Gitlab::Utils::Override

      def epics
        epics = EpicsFinder.new(current_user, issuable_params).execute.search(query)

        apply_sort(epics)
      end

      override :work_items
      def work_items(finder_params = {})
        finder_params = issuable_params.merge(
          finder_params,
          include_descendants: true,
          include_ancestors: false
        )

        work_items = ::WorkItems::WorkItemsFinder.new(current_user, finder_params).execute.search(query)
        work_items = by_work_item_type_ids(work_items)
        apply_sort(work_items, scope: 'work_items')
      end
    end
  end
end
