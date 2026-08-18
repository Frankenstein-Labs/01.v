# frozen_string_literal: true

module EE
  module API
    module AwardEmoji
      extend ActiveSupport::Concern

      prepended do
        helpers do
          def present(objects, options = {})
            if awardable.is_a?(::Epic)
              super(objects, options.merge(
                with: ::API::Entities::LegacyEpicAwardEmoji,
                epic: awardable
              ))
            else
              super
            end
          end
        end
      end
    end
  end
end
