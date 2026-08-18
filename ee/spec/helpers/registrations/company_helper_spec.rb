# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::CompanyHelper, feature_category: :onboarding do
  describe '#create_company_form_data', :with_trial_types do
    let(:user) { build_stubbed(:user, onboarding_status_registration_type: 'trial') }
    let(:trial_duration) { 30 }
    let(:extra_params) do
      {
        jobs_to_be_done_other: '_params_jobs_to_be_done_other'
      }
    end

    let(:params) do
      ActionController::Parameters.new(extra_params)
    end

    before do
      allow(helper).to receive_messages(params: params, current_user: user)
    end

    subject(:form_data) { helper.create_company_form_data(::Onboarding::StatusPresenter.new({}, {}, user)) }

    it 'has default data' do
      attributes = {
        user: {
          firstName: user.first_name,
          lastName: user.last_name,
          companyName: nil,
          phoneNumber: nil,
          country: '',
          state: '',
          showNameFields: false,
          emailDomain: user.email_domain
        },
        submitPath: "/users/sign_up/company?#{extra_params.to_query}",
        showFormFooter: true,
        trackActionForErrors: 'trial_registration',
        trialDuration: trial_duration
      }.deep_stringify_keys

      expect(form_data).to match(::Gitlab::Json.generate(attributes))
    end

    context 'when params are provided on failure' do
      let(:params) { super().merge('company_name' => '_some_company_', 'country' => 'US', 'state' => 'CA') }

      it 'allows overriding default data with params' do
        attributes = {
          user: {
            firstName: user.first_name,
            lastName: user.last_name,
            companyName: '_some_company_',
            phoneNumber: nil,
            country: 'US',
            state: 'CA',
            showNameFields: false,
            emailDomain: user.email_domain
          },
          submitPath: "/users/sign_up/company?#{extra_params.to_query}",
          showFormFooter: true,
          trackActionForErrors: 'trial_registration',
          trialDuration: trial_duration
        }.deep_stringify_keys

        expect(form_data).to match(::Gitlab::Json.generate(attributes))
      end
    end
  end
end
