# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoPro
      class AdvantagesListComponent < ViewComponent::Base
        private

        delegate :sprite_icon, to: :helpers

        def advantages
          [
            s_('DuoProTrial|Code completion and code generation with Code Suggestions'),
            s_('DuoProTrial|Test Generation'),
            s_('DuoProTrial|Code Refactoring'),
            s_('DuoProTrial|Code Explanation'),
            s_('DuoProTrial|Chat within the IDE'),
            s_('DuoProTrial|Organizational user controls')
          ]
        end
      end
    end
  end
end
