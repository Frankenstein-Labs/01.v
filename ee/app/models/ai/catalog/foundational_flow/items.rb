# frozen_string_literal: true

module Ai
  module Catalog
    class FoundationalFlow
      module Items
        extend ActiveSupport::Concern

        FLOW_DEFINITIONS = [
          Definitions::CodeReview,
          Definitions::RiskClassification,
          Definitions::SastFpDetection,
          Definitions::ResolveSastVulnerability,
          Definitions::Developer,
          Definitions::FixPipeline,
          Definitions::ConvertToGlCi,
          Definitions::RecommendReviewers,
          Definitions::SecretsFpDetection,
          Definitions::ResolveDependencyBump,
          Definitions::SecurityReview,
          Definitions::BusinessContextSecurityGuidelines
        ].freeze
        private_constant :FLOW_DEFINITIONS

        class_methods do
          # Make sure static data is always loaded in English and let `translated_display_name` and
          # `translated_description` deal with translations when required.
          # This ensures catalog items records are created in English and translated on the fly when needed.
          def fixed_items
            Gitlab::I18n.with_locale(:en) do
              FLOW_DEFINITIONS.map(&:configuration)
            end
          end
        end
      end
    end
  end
end
