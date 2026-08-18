# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoEnterprise
      class TopPageComponent < Trials::TopPageComponent
        extend ::Gitlab::Utils::Override

        private

        override :title
        def title
          s_('DuoEnterpriseTrial|Start your free GitLab Duo Enterprise trial')
        end
      end
    end
  end
end
