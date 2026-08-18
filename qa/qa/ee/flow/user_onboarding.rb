# frozen_string_literal: true

module QA
  module EE
    module Flow
      module UserOnboarding
        extend self

        def onboard_user
          EE::Page::Registration::Welcome.perform do |welcome_page|
            if welcome_page.has_get_started_button?
              welcome_page.select_role('Other')
              welcome_page.choose_setup_for_just_me_if_available
              welcome_page.choose_create_a_new_project_if_available
              welcome_page.click_get_started_button
            end
          end
        end

        def create_initial_project
          EE::Page::Registration::Welcome.perform(&:create_initial_project)
        end
      end
    end
  end
end
