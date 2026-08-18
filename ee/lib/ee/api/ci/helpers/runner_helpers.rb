# frozen_string_literal: true

module EE
  module API
    module Ci
      module Helpers
        module RunnerHelpers
          extend ActiveSupport::Concern

          prepended do
            params :create_runner_params_ee do
              optional :token_expires_at, type: DateTime,
                desc: 'The expiration time for the runner authentication token (ISO 8601 format). ' \
                  'Must be between 5 minutes and 15 days in the future, ' \
                  'and cannot exceed instance/group/project limits.'
              optional :token_rotation_deadline, type: DateTime,
                desc: 'The deadline for token rotation (ISO 8601 format). ' \
                  'Must be specified with token_expires_at and be <= token_expires_at.'
            end
          end
        end
      end
    end
  end
end
