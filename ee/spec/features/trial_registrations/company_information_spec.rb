# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Company Information', :with_trial_types, :js, feature_category: :activation do
  include SaasRegistrationHelpers

  let_it_be_with_reload(:user) do
    create(:user, onboarding_in_progress: true, onboarding_status_registration_type: 'trial',
      onboarding_status_initial_registration_type: 'trial')
  end

  let_it_be(:fields) do
    [
      'Company name',
      'Country',
      'Telephone number (optional)'
    ]
  end

  before do
    stub_saas_features(onboarding: true)

    sign_in(user)
    visit new_users_sign_up_company_path
  end

  it 'shows the expected fields' do
    fields.each { |field| expect(page).to have_content(field) }
  end

  context 'with company information to create trial concerns' do
    using RSpec::Parameterized::TableSyntax

    let(:extra_params) { {} }
    let(:params) do
      {
        first_name: user.first_name,
        last_name: user.last_name,
        company_name: 'Test Company',
        phone_number: '+1234567890',
        country: 'US',
        state: 'FL'
      }.merge(extra_params)
    end

    where(:service_response, :current_path, :page_content) do
      ServiceResponse.success                   | new_users_sign_up_group_path | 'Create or import your first project'
      ServiceResponse.error(message: 'failed')  | users_sign_up_company_path   | 'failed'
    end

    with_them do
      it 'verifies existing name fields filled and redirects to correct path' do
        fill_company_form_fields

        expect_next_instance_of(
          GitlabSubscriptions::CreateCompanyLeadService,
          user: user,
          params: ActionController::Parameters.new(params).permit!
        ) do |service|
          expect(service).to receive(:execute).and_return(service_response)
        end

        click_on s_('Trial|Continue')

        expect(page).to have_current_path(current_path, ignore_query: true)
        expect(page).to have_content(page_content)
      end
    end

    context 'when country selected requires a state' do
      it 'submits the form when state is selected' do
        expect_next_instance_of(
          GitlabSubscriptions::CreateCompanyLeadService,
          user: user,
          params: ActionController::Parameters.new(params).permit!
        ) do |service|
          expect(service).to receive(:execute).and_return(ServiceResponse.success)
        end

        fill_in 'company_name', with: 'Test Company'
        select_from_listbox 'United States of America', from: 'Select a country or region'

        click_on s_('Trial|Continue')

        expect(page).to have_content('State or province is required.')

        select_from_listbox 'Florida', from: 'Select state or province'
        fill_in 'phone_number', with: '+1234567890'

        click_on s_('Trial|Continue')

        expect(page).to have_current_path(new_users_sign_up_group_path, ignore_query: true)
        expect(page).to have_content('Create or import your first project')
      end
    end

    context 'when first and last name are entered by the user' do
      let(:extra_params) { { first_name: 'Foo', last_name: 'Bar' } }

      before do
        user.update!(name: 'Bob')
      end

      it 'fills in first_name and last_name and submits successfully' do
        page.refresh

        fill_in 'first_name', with: 'Foo'
        fill_in 'last_name', with: 'Bar'
        fill_company_form_fields

        expect_next_instance_of(
          GitlabSubscriptions::CreateCompanyLeadService,
          user: user,
          params: ActionController::Parameters.new(params).permit!
        ) do |service|
          expect(service).to receive(:execute).and_return(ServiceResponse.success)
        end

        click_on s_('Trial|Continue')

        expect(page).to have_current_path(new_users_sign_up_group_path, ignore_query: true)
        expect(page).to have_content('Create or import your first project')
      end
    end
  end
end
