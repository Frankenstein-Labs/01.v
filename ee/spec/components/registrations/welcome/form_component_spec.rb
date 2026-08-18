# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::Welcome::FormComponent, :aggregate_failures, feature_category: :onboarding do
  let(:user) { build(:user, company: 'Acme Corp') }
  let(:form_params) { {}.with_indifferent_access }

  subject(:component) { render_inline(described_class.new(user, form_params)) && page }

  context 'with default content' do
    it { is_expected.to have_content('Welcome to GitLab') }

    it 'renders the form mount point with form data' do
      expect(component).to have_css('#js-free-welcome-form')
    end

    it 'submits to the welcome path without a step when none is supplied' do
      expect(parsed_view_model['submitPath']).to eq(users_sign_up_welcome_path)
    end

    it 'wires the setup_for_company copy from the free registration type' do
      expect(parsed_view_model['setupForCompanyLabel'])
        .to eq(::Onboarding::FreeRegistration.setup_for_company_label_text)
    end

    it 'includes role options' do
      expect(parsed_view_model['roleOptions'])
        .to include(hash_including('value' => '0', 'text' => 'Software Developer'))
    end

    it 'includes registration objective options' do
      expect(parsed_view_model['registrationObjectiveOptions'])
        .to include(hash_including('text' => 'A different reason'))
    end

    it 'includes user data fields' do
      user_data = parsed_view_model['userData']

      expect(user_data['companyName']).to eq('Acme Corp')
      expect(user_data['showNameFields']).to be(false)
      expect(user_data['role']).to eq('')
      expect(user_data['setupForCompany']).to eq('')
      expect(user_data['registrationObjective']).to eq('')
    end
  end

  context 'when a step is carried through on a resubmit' do
    let(:form_params) { { step: ::Onboarding::FreeNamespaceCreateService::GROUP_FLOW }.with_indifferent_access }

    it 'submits at that step so the onboarding status update is not re-run' do
      expect(parsed_view_model['submitPath'])
        .to eq(users_sign_up_welcome_path(step: ::Onboarding::FreeNamespaceCreateService::GROUP_FLOW))
    end
  end

  context 'when params override user model values' do
    let(:user) { build(:user, first_name: 'John', last_name: 'Doe', company: 'Acme Corp') }
    let(:form_params) do
      {
        first_name: 'Jane',
        last_name: 'Smith',
        company_name: 'Globex',
        onboarding_status_setup_for_company: 'true'
      }.with_indifferent_access
    end

    it 'uses params values over user model values' do
      user_data = parsed_view_model['userData']

      expect(user_data['firstName']).to eq('Jane')
      expect(user_data['lastName']).to eq('Smith')
      expect(user_data['companyName']).to eq('Globex')
      expect(user_data['setupForCompany']).to eq('true')
    end
  end

  def parsed_view_model
    data_view_model = component.find('#js-free-welcome-form')['data-view-model']
    ::Gitlab::Json.safe_parse(data_view_model)
  end
end
