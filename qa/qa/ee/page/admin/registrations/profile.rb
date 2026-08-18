# frozen_string_literal: true

module QA
  module EE
    module Page
      module Admin
        module Registrations
          module Profile
            extend QA::Page::PageConcern

            def self.prepended(base)
              super

              base.class_eval do
                view 'ee/app/views/admin/registrations/profiles/_ee_profile_fields.html.haml' do
                  element 'country'
                end
              end
            end

            private

            # EE adds a required country select to the onboarding profile step. Pick the
            # first option with a value so we do not depend on a specific country's
            # localized label. Overrides the CE no-op.
            def select_first_country
              return unless has_element?('country', wait: 0)

              option = find_element('country').all('option', visible: :all).find { |o| o.value.present? }
              raise "No selectable country option found in the onboarding profile country dropdown" unless option

              option.select_option
            end
          end
        end
      end
    end
  end
end
