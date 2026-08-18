# frozen_string_literal: true

module API
  module Entities
    module Scim
      class Groups < Grape::Entity
        expose :schemas
        expose :total_results, as: :totalResults
        expose :items_per_page, as: :itemsPerPage
        expose :start_index, as: :startIndex

        expose :resources, as: :Resources, using: ::API::Entities::Scim::Group

        private

        DEFAULT_SCHEMA = 'urn:ietf:params:scim:api:messages:2.0:ListResponse'

        def schemas
          [DEFAULT_SCHEMA]
        end

        def total_results
          object[:total_results] || resources.size
        end

        def items_per_page
          object[:items_per_page] || Kaminari.config.default_per_page
        end

        def start_index
          object[:start_index].presence || 1
        end

        def resources
          object[:resources] || []
        end
      end
    end
  end
end
