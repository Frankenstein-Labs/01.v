# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoEnterprise
      class AdvantagesListComponent < ViewComponent::Base
        private

        delegate :sprite_icon, to: :helpers

        def advantages
          [
            s_('DuoEnterpriseTrial|Stay on top of regulatory requirements with self-hosted model deployment'),
            s_('DuoEnterpriseTrial|Enhance security and remediate vulnerabilities efficiently'),
            s_('DuoEnterpriseTrial|Quickly remedy broken pipelines to deliver products faster'),
            s_('DuoEnterpriseTrial|Gain deeper insights into GitLab Duo usage patterns'),
            s_('DuoEnterpriseTrial|Maintain control and keep your data safe')
          ]
        end
      end
    end
  end
end
