# frozen_string_literal: true

module WorkItems
  module TypesFramework
    module SystemDefined
      module Definitions
        module TestCase
          class << self
            def widgets
              %w[
                ai_session
                award_emoji
                current_user_todos
                description
                linked_items
                notes
                notifications
                participants
                time_tracking
              ]
            end

            def widget_options
              {}
            end

            def configuration
              {
                id: 3,
                name: 'Test Case',
                base_type: 'test_case',
                icon_name: "work-item-test-case"
              }
            end

            def use_legacy_view?
              true
            end

            def license_name
              # Check which license we should use here, :requirements or :quality_management.
              :requirements
            end

            def creatable?
              false
            end

            def can_be_conversion_target?
              false
            end

            def filterable_list_view?
              false
            end

            def disabled_workflow_type?
              true
            end

            def configurable?
              false
            end
          end
        end
      end
    end
  end
end
