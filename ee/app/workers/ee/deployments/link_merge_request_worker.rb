# frozen_string_literal: true

module EE
  module Deployments
    module LinkMergeRequestWorker
      extend ::Gitlab::Utils::Override

      override :after_perform
      def after_perform(deployment)
        return unless deployment.success?

        Dora::Watchers.process_event(deployment, :successful)
      end
    end
  end
end
