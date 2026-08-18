# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoPro
      class ResubmitComponent < Trials::ResubmitComponent
        extend ::Gitlab::Utils::Override

        private

        override :top_page_component
        def top_page_component
          GitlabSubscriptions::Trials::DuoPro::TopPageComponent
        end
      end
    end
  end
end
