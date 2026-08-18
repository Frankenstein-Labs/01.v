# frozen_string_literal: true

module EE
  module Gitlab
    module UserAccess
      extend ::Gitlab::Utils::Override

      override :can_run_pipeline_on_branch?
      def can_run_pipeline_on_branch?(ref)
        result = super
        return result if result
        return false unless user

        user.can?(:create_bot_pipeline, container)
      end
    end
  end
end
