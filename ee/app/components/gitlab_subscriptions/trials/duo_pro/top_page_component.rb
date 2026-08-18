# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoPro
      class TopPageComponent < Trials::TopPageComponent
        extend ::Gitlab::Utils::Override

        private

        override :title
        def title
          s_('DuoProTrial|Start your free GitLab Duo Pro trial')
        end
      end
    end
  end
end
