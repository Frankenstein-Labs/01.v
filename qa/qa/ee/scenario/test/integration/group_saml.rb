# frozen_string_literal: true

module QA
  module EE
    module Scenario
      module Test
        module Integration
          class GroupSAML < QA::Scenario::Template
            include QA::Scenario::Bootable
            include QA::Scenario::SharedAttributes

            tags :group_saml

            pipeline_mappings test_on_omnibus: %w[group-saml]
          end
        end
      end
    end
  end
end
