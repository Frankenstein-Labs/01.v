# frozen_string_literal: true

module Search
  module Elastic
    module Sorts
      class Base
        SORT_MAPPINGS = {
          created_at_asc: { created_at: { order: 'asc' } },
          created_at_desc: { created_at: { order: 'desc' } },
          updated_at_asc: { updated_at: { order: 'asc' } },
          updated_at_desc: { updated_at: { order: 'desc' } }
        }.freeze

        class << self
          def sort_by(query_hash:, options:)
            sort_hash = build_sort(options[:order_by], options[:sort])
            query_hash.merge(sort: sort_hash)
          end

          private

          def build_sort(order_by, sort)
            sort_and_direction = ::Search::SortOptions.sort_and_direction(order_by, sort)
            self::SORT_MAPPINGS.fetch(sort_and_direction, {})
          end
        end
      end
    end
  end
end
