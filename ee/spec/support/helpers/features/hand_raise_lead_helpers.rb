# frozen_string_literal: true

module Features
  module HandRaiseLeadHelpers
    include ListboxHelpers

    def expect_fill_in_and_submit_hand_raise_lead(
      user, namespace, glm_content: nil, product_interaction: 'Hand Raise PQL')
      form_data = {
        first_name: user.first_name,
        last_name: user.last_name,
        phone_number: '+1 23 456-78-90',
        company_name: user.company,
        country: { id: 'US', name: 'United States of America' },
        state: { id: 'CA', name: 'California' }
      }

      hand_raise_lead_params = {
        "first_name" => form_data[:first_name],
        "last_name" => form_data[:last_name],
        "company_name" => form_data[:company_name],
        "phone_number" => form_data[:phone_number],
        "country" => form_data.dig(:country, :id),
        "state" => form_data.dig(:state, :id),
        "namespace_id" => namespace.id,
        "comment" => '',
        "glm_content" => glm_content,
        "product_interaction" => product_interaction,
        "work_email" => user.email,
        "uid" => user.id,
        "setup_for_company" => user.onboarding_status_setup_for_company,
        "provider" => "gitlab",
        "existing_plan" => namespace.actual_plan.name,
        "glm_source" => 'gitlab.com'
      }

      lead_params = ActionController::Parameters.new(hand_raise_lead_params).permit!

      expect_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
        expect(service).to receive(:execute).with(lead_params).and_return(ServiceResponse.success)
      end

      fill_hand_raise_lead_form_and_submit(form_data)
    end

    def fill_hand_raise_lead_form_and_submit(form_data)
      within_testid('hand-raise-lead-modal') do
        aggregate_failures do
          expect(page).to have_content('Contact our Sales team')
          expect(page).to have_field('First name', with: form_data[:first_name])
          expect(page).to have_field('Last name', with: form_data[:last_name])
          expect(page).to have_field('Company name', with: form_data[:company_name])
        end

        fill_in 'Telephone number', with: form_data[:phone_number]
        select_from_listbox form_data.dig(:country, :name), from: 'Select a country or region'
        select_from_listbox form_data.dig(:state, :name), from: 'Select state or province'

        click_button 'Submit information'
      end
    end
  end
end
