# frozen_string_literal: true

module Gitlab
  module Usage
    module Metrics
      module Instrumentations
        module SecretsManagement
          class CountEnrolledNamespacesMetric < DatabaseMetric
            relation { ::SecretsManagement::NamespaceEnrollment }

            operation :count
          end
        end
      end
    end
  end
end
