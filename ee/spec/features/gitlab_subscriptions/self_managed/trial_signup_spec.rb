# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Self-managed trial signup', :js, feature_category: :acquisition do
  include ListboxHelpers

  let_it_be(:user) { create(:user) }

  let(:form_data) do
    {
      first_name: user.first_name,
      last_name: user.last_name,
      email_address: user.email,
      company_name: 'ACME Corp',
      country: { id: 'US', name: 'United States of America' },
      state: { id: 'CA', name: 'California' },
      consent_to_marketing: '1'
    }
  end

  before do
    sign_in(user)
  end

  context 'when feature flag is enabled' do
    context 'when trial submission succeeds' do
      it 'fills out form, submits and redirects to admin subscription page' do
        visit new_self_managed_trials_path

        fill_in_trial_form

        stub_trial_api_success
        click_button s_('Trial|Get started')

        expect(page).to have_current_path(dashboard_projects_path)
      end
    end

    context 'when trial submission fails with duplicate email error' do
      it 'displays error and stays on the form' do
        visit new_self_managed_trials_path

        fill_in_trial_form

        stub_trial_api_duplicate_email_error
        click_button s_('Trial|Get started')

        expect(page).to have_content(s_('Trial|Start your free Ultimate trial!'))
        expect(page).to have_content('email address was already registered')
      end
    end

    context 'when trial submission fails with activation error' do
      it 'displays resubmit component with error message' do
        visit new_self_managed_trials_path

        fill_in_trial_form

        stub_trial_api_general_activation_error
        click_button s_('Trial|Get started')

        expect(page).to have_content(_('Trial registration unsuccessful'))
        expect(page).to have_content('GitLab Support')
        expect(page).to have_button('Resubmit request')
      end
    end
  end

  def fill_in_trial_form
    fill_in 'first_name', with: form_data[:first_name]
    fill_in 'last_name', with: form_data[:last_name]
    fill_in 'email_address', with: form_data[:email_address]
    fill_in 'company_name', with: form_data[:company_name]
    select_from_listbox form_data.dig(:country, :name), from: s_('Trial|Select a country or region')
    select_from_listbox form_data.dig(:state, :name), from: s_('Trial|Select state or province')
    check(s_('Trial|I agree that GitLab can contact me by email about its product, services, or events.'))
  end

  def trial_params
    {
      trial: {
        name: "#{form_data[:first_name]} #{form_data[:last_name]}",
        email: form_data[:email_address],
        language: 'en',
        company: form_data[:company_name],
        country: form_data.dig(:country, :id),
        state: form_data.dig(:state, :id),
        consent_to_marketing: form_data[:consent_to_marketing]
      }
    }
  end

  def stub_trial_api_success
    allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_self_managed_ultimate_trial)
      .with(trial_params)
      .and_return({ success: true, data: { 'activation_code' => 'abc123' } })

    activate_service = instance_double(::GitlabSubscriptions::ActivateService)
    allow(::GitlabSubscriptions::ActivateService).to receive(:new).and_return(activate_service)
    allow(activate_service).to receive(:execute).with('abc123').and_return({ success: true })
  end

  def stub_trial_api_duplicate_email_error
    allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_self_managed_ultimate_trial)
      .with(trial_params)
      .and_return({
        success: false,
        data: { error_attribute_map: { base: 'only_one_trial_per_email_and_type' }, status: :unprocessable_entity }
      })
  end

  def stub_trial_api_general_activation_error
    allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_self_managed_ultimate_trial)
      .with(trial_params)
      .and_return({
        success: false,
        data: { error_attribute_map: { base: 'generic_error' }, status: :unprocessable_entity }
      })
  end
end
