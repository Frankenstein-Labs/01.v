# frozen_string_literal: true

module QA
  module EE
    module Page
      module Registration
        # The trial registration page renders the unified sign-up partial, so
        # it inherits SignUp#register_user; only the path differs. The elements
        # are re-declared against the unified partial so the selectors sanity
        # check validates the correct view file.
        class TrialRegistration < QA::Page::Registration::SignUp
          view 'ee/app/views/devise/registrations/_signup_box_form_unified.html.haml' do
            element 'new-user-first-name-field'
            element 'new-user-last-name-field'
            element 'new-user-email-field'
          end

          def self.path
            "/-/trial_registrations/new"
          end
        end
      end
    end
  end
end
