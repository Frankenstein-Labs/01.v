# frozen_string_literal: true

module Gitlab
  module Duo
    module CodeReview
      module_function

      def enabled?(user:, container:)
        ModeResolver.new(user: user, container: container).enabled?
      end

      def mode(user:, container:)
        ModeResolver.new(user: user, container: container).mode
      end

      def dap?(user:, container:)
        mode(user:, container:) == :dap
      end
    end
  end
end
