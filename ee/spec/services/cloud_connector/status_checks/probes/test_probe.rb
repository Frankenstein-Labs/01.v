# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      # Returns a canned response, useful for unit testing.
      class TestProbe < BaseProbe
        extend ::Gitlab::Utils::Override

        validate :check_success
        after_validation :collect_details

        def initialize(success: true)
          @success = success
        end

        private

        def check_success
          errors.add(:base, 'NOK') unless @success
        end

        def collect_details
          details.add(:test, 'true')
        end

        override :success_message
        def success_message
          'OK'
        end
      end
    end
  end
end
