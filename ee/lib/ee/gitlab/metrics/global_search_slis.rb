# frozen_string_literal: true

module EE
  module Gitlab
    module Metrics
      module GlobalSearchSlis
        def self.prepended(base)
          base.singleton_class.prepend(ClassMethods)
        end

        module ClassMethods
          extend ::Gitlab::Utils::Override

          override :endpoint_ids
          def endpoint_ids
            endpoints = super

            endpoints.push('SearchController#aggregations') if ::Gitlab::Metrics::Environment.web?

            endpoints
          end
        end
      end
    end
  end
end
