# frozen_string_literal: true

module Search
  module Elastic
    module Sorts
      class WorkItem < Base
        SORT_MAPPINGS = Base::SORT_MAPPINGS.merge(
          popularity_asc: { upvotes: { order: 'asc' } },
          popularity_desc: { upvotes: { order: 'desc' } },
          milestone_due_asc: { milestone_due_date: { order: 'asc' } },
          milestone_due_desc: { milestone_due_date: { order: 'desc' } },
          weight_asc: { weight: { order: 'asc' } },
          weight_desc: { weight: { order: 'desc' } },
          health_status_asc: { health_status: { order: 'asc' } },
          health_status_desc: { health_status: { order: 'desc' } },
          closed_at_asc: { closed_at: { order: 'asc' } },
          closed_at_desc: { closed_at: { order: 'desc' } },
          due_date_asc: { due_date: { order: 'asc' } },
          due_date_desc: { due_date: { order: 'desc' } }
        ).freeze
      end
    end
  end
end
