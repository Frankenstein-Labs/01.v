# frozen_string_literal: true

module GitlabSubscriptions
  module SelfManaged
    class InInstanceSelfManagedTrialActivationConstraint
      def matches?(_request)
        Feature.enabled?(:in_instance_self_managed_trial_activation, :instance)
      end
    end
  end
end
