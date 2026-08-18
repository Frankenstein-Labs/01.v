# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::CreateAddOnLeadService, feature_category: :acquisition do
  let_it_be(:user) { create(:user, last_name: 'Jones') }

  describe '#execute' do
    let(:expected_params) do
      {
        company_name: 'Gitlab',
        first_name: user.first_name,
        last_name: user.last_name,
        phone_number: '1111111111',
        country: 'US',
        work_email: user.email,
        uid: user.id,
        setup_for_company: user.onboarding_status_setup_for_company,
        skip_email_confirmation: true,
        gitlab_com_trial: true,
        provider: 'gitlab',
        product_interaction: 'duo_pro_trial',
        preferred_language: user.preferred_language,
        opt_in: user.onboarding_status_email_opt_in
      }
    end

    let(:lead_params) { { trial_user: ActionController::Parameters.new(expected_params).permit! } }

    subject(:execute) { described_class.new.execute(lead_params) }

    it 'successfully creates a lead' do
      allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_addon_trial_lead).with(lead_params)
                                                                           .and_return({ success: true })

      expect(execute).to be_success
    end

    it 'errors while creating lead' do
      allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_addon_trial_lead)
                                                     .and_return({ success: false, data: { errors: '_fail_' } })

      expect(execute).to be_error.and have_attributes(message: '_fail_')
    end
  end
end
