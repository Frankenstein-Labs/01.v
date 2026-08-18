# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Policies
          class PolicyEditor < QA::Page::Base
            view 'ee/app/assets/javascripts/security_orchestration/components/policy_editor/policy_type_selector.vue' do
              element 'policy-selection-wizard'
            end

            view 'ee/app/assets/javascripts/security_orchestration/components/policy_editor/editor_layout.vue' do
              element 'policy-name-text'
              element 'save-policy'
            end

            def has_policy_selection?(selector)
              has_element?(selector)
            end

            def click_save_policy_button
              click_element('save-policy')
            end

            def fill_name
              fill_element('policy-name-text', 'New policy')
            end

            def select_scan_execution_policy
              click_element('select-policy-scan_execution_policy')
            end
          end
        end
      end
    end
  end
end
